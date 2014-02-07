/*
 * Copyright (c) 2014 Team Trinidad and contributors http://github.com/trinidad
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package rb.trinidad.context;

import java.lang.reflect.InvocationTargetException;
import java.security.Provider;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;
import javax.servlet.ServletContext;

import org.apache.catalina.Context;
import org.apache.catalina.Lifecycle;
import org.apache.catalina.LifecycleEvent;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.LifecycleListener;
import org.apache.catalina.loader.WebappClassLoader;
import org.apache.catalina.loader.WebappLoader;

import org.jruby.Ruby;
import org.jruby.util.JRubyClassLoader;
//import org.jruby.rack.RackApplication;
//import org.jruby.rack.RackApplicationFactoryDecorator;

/**
 * Default (a bit JRuby-aware) web-application (class) loader.
 *
 * @see org.apache.catalina.loader.WebappLoader
 * @see org.apache.catalina.loader.WebappClassLoader
 *
 * @author kares
 */
public class DefaultLoader extends WebappLoader {

    private static final org.apache.juli.logging.Log log =
        org.apache.juli.logging.LogFactory.getLog( DefaultLoader.class );

    private boolean forceSecurityProviderCleanup;

    public DefaultLoader() {
        super();
    }

    public DefaultLoader(ClassLoader parent) {
        super(parent);
    }

    public boolean isForceSecurityProviderCleanup() {
        return forceSecurityProviderCleanup;
    }

    public void setForceSecurityProviderCleanup(boolean forceCleanup) {
        this.forceSecurityProviderCleanup = forceCleanup;
    }

    @Override
    public String toString() {
        final String str = super.toString();
        return str.replace("WebappLoader", getClass().getCanonicalName());
    }

    @Override
    protected void startInternal() throws LifecycleException {
        super.startInternal();

        getContextBang().addLifecycleListener(contextListener = new ContextListener());
    }

    @Override
    protected void stopInternal() throws LifecycleException {
        if ( contextListener != null ) {
            getContextBang().removeLifecycleListener(contextListener);
            contextListener = null;
        }

        Collection<Ruby> managedRuntimes = null; // only 1 for threadsafe!
        Set<JRubyClassLoader> jrubyLoaders = null;
        if ( rackFactory != null ) {
            if (log.isDebugEnabled()) {
                log.debug("Resolved rack.factory: " + rackFactory + " loader: " + rackFactory.getClass().getClassLoader());
            }
            managedRuntimes = getManagedRuntimes(rackFactory);
            if ( managedRuntimes != null ) {
                jrubyLoaders = new LinkedHashSet<JRubyClassLoader>(managedRuntimes.size());
                for ( Ruby runtime : managedRuntimes ) {
                    jrubyLoaders.add( runtime.getJRubyClassLoader() );
                }
                log.debug("JRuby loader(s) used for managed runtime(s): " + managedRuntimes);
            }
        }
        else {
            log.info("Could not resolve rack.factory for context: " + getContainer());
        }

        if ( getClassLoader() != null ) {
            removeLoadedSecurityProviderForOpenSSL(jrubyLoaders);
        }

        rackFactory = null;
        super.stopInternal();
    }

    private transient ContextListener contextListener;
    private transient Object rackFactory; // org.jruby.rack.RackApplicationFactoryDecorator

    // NOTE: we'll need to get the JRuby-Rack stuff before stop() happens
    // ... since atrrs get cleaned by the time our stop method is executed
    private void contextStopEvent() {
        rackFactory = getServletContext().getAttribute("rack.factory");
    }

    private Collection<Ruby> getManagedRuntimes(final Object rackFactory) {
        try { // public Collection<RackApplication> getManagedApplications()
            final Collection apps = (Collection)
                rackFactory.getClass().getMethod("getManagedApplications").invoke(rackFactory);
            final Collection<Ruby> runtimes = new LinkedHashSet<Ruby>(apps.size());
            for ( Object app : apps ) { // most likely only one (threadsafe!)
                Object runtime = app.getClass().getMethod("getRuntime").invoke(app);
                runtimes.add( (Ruby) runtime );
            }

            if ( runtimes == null || runtimes.isEmpty() ) {
                log.info("No managed runtimes found for context: " + getContainer());
            }
            else {
                if (log.isDebugEnabled()) {
                    log.debug("Found " + runtimes.size() + " managed runtimes for context: " + getContainer());
                }
            }

            return runtimes;
        }
        catch (NoSuchMethodException e) {
            log.info("Failed getting managed runtimes from rack.factory", e);
        }
        catch (IllegalAccessException e) {
            log.info("Failed getting managed runtimes from rack.factory", e);
        }
        catch (InvocationTargetException e) {
            log.info("Failed getting managed runtimes from rack.factory", e.getTargetException());
        }
        return null;
    }

    private ClassLoader getClassLoaderBang() {
        final ClassLoader classLoader = getClassLoader();
        if ( classLoader == null ) {
            throw new IllegalStateException("unexpected state " + getStateName() + " no class-loader");
        }
        return classLoader;
    }

    private Context getContextBang() {
        final Context context = (Context) getContainer();
        if ( context == null ) {
            throw new IllegalStateException("unexpected state " + getStateName() + " no context (container)");
        }
        return context;
    }

    private ServletContext getServletContext() {
        return getContextBang().getServletContext();
    }

    private void removeLoadedSecurityProviderForOpenSSL(final Collection<JRubyClassLoader> appLoaders) {
        final Provider bcProvider = java.security.Security.getProvider("BC");
        // the registered : org.bouncycastle.jce.provider.BouncyCastleProvider
        // JRuby's latest OpenSSL impl does : Security.addProvider(BC_PROVIDER)
        // @see org.jruby.ext.openssl.OpenSSLReal
        if ( bcProvider == null ) {
            log.debug("Security provider 'BC' no registered");
            return; // not loaded at all - nothing to-do
        }
        if ( isLoadedByParentLoader(bcProvider.getClass()) ) {
            log.debug("Security provider 'BC' loaded by parent loader");
            return; // loaded but not by us - nothing to-do
            // NOTE: JRuby handles this correctly as well, adds the BC provider
            // only if ... java.security.Security.getProvider("BC") == null
        }

        final ClassLoader bcLoader = bcProvider.getClass().getClassLoader();
        // make sure we do not de-register 'BC' setup by another web-app :
        if ( appLoaders != null && appLoaders.contains(bcLoader) ) {
            log.info("Removing 'BC' security provider (likely registered by jruby-openssl)");
        }
        else {
            if ( ! isForceSecurityProviderCleanup() ) return;
            log.warn("Removing 'BC' security provider loaded by class-loader: " + bcProvider.getClass().getClassLoader());
        }
        synchronized(java.security.Security.class) {
            if ( java.security.Security.getProvider("BC") != null ) {
                java.security.Security.removeProvider("BC"); // since we loaded it
            }
        }
    }

    private void performJDBCDriverCleanup() {
        // TODO unregister with DriverManager

        performMySQLDriverCleanup();
    }

    private void performMySQLDriverCleanup() { // MySQL JDBC support
        Thread cleanupThread = checkAbandonedConnectionCleanupThread();
        if ( cleanupThread != null ) {
            cleanupThread.getContextClassLoader();
        }
    }

    private Thread checkAbandonedConnectionCleanupThread() {
        // thread's name: "Abandoned connection cleanup thread"

        return null;
    }

    private void shutdownMySQLAbandonedConnectionCleanupThread() {
        final String className = "com.mysql.jdbc.AbandonedConnectionCleanupThread";
        try {
            Class threadClass = Class.forName(className, false, getClassLoader());
            if (threadClass != null) {
                threadClass.getMethod("shutdown").invoke(null); // stop's the thread
                log.info("MySQL connection cleanup thread shutdown has been triggered");
            }
        }
        catch (ClassNotFoundException e) {
            log.debug("MySQL connection cleanup thread not present", e);
        }
        catch (NoSuchMethodException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e);
        }
        catch (IllegalAccessException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e);
        }
        catch (InvocationTargetException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e.getTargetException());
        }
    }

    private boolean isLoadedByParentLoader(final Class<?> clazz) {
        final ClassLoader clazzLoader = clazz.getClassLoader();
        ClassLoader parentLoader = getClassLoaderBang().getParent();
        while ( parentLoader != null ) {
            if ( clazzLoader == parentLoader ) return true;
            parentLoader = parentLoader.getParent();
        }
        return false;
    }

    private boolean isLoadedByThisLoader(final Object obj) {
        final ClassLoader classLoader = getClassLoaderBang();
        return isLoadedBy(obj, classLoader, false);
    }

    private static boolean isLoadedBy(final Object obj, final ClassLoader loader, final boolean checkParent) {
        if ( obj == null ) return false;

        final Class<?> clazz = (obj instanceof Class) ? (Class<?>) obj : obj.getClass();

        ClassLoader clazzLoader = clazz.getClassLoader();
        while ( clazzLoader != null ) {
            if ( clazzLoader == loader ) return true;
            if ( ! checkParent ) break;
            clazzLoader = clazzLoader.getParent();
        }
        return false;
    }

    private class ContextListener implements LifecycleListener {

        @Override
        public void lifecycleEvent(LifecycleEvent event) {
            if ( event.getType() == Lifecycle.STOP_EVENT ) {
                DefaultLoader.this.contextStopEvent();
            }
        }

    }

}
