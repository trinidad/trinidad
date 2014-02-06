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

import java.security.Provider;

import org.apache.catalina.Context;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.loader.WebappClassLoader;
import org.apache.catalina.loader.WebappLoader;

//import org.jruby.Ruby;

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

    public DefaultLoader() {
        super();
    }

    public DefaultLoader(ClassLoader parent) {
        super(parent);
    }

    @Override
    public String toString() {
        final String str = super.toString();
        return str.replace("WebappLoader", getClass().getCanonicalName());
    }

    @Override
    protected void startInternal() throws LifecycleException {
        super.startInternal();

        // Context context = getContext();
    }

    @Override
    protected void stopInternal() throws LifecycleException {
        if ( getClassLoader() != null ) {
            removeLoadedSecurityProviderForOpenSSL();
        }
        super.stopInternal();
    }

    protected final Context getContext() {
        return (Context) getContainer();
    }

    private void removeLoadedSecurityProviderForOpenSSL() {
        final Provider bcProvider = java.security.Security.getProvider("BC");
        // the registered : org.bouncycastle.jce.provider.BouncyCastleProvider
        // JRuby's latest OpenSSL impl does : Security.addProvider(BC_PROVIDER)
        // @see org.jruby.ext.openssl.OpenSSLReal
        if ( bcProvider == null ) {
            return; // not loaded at all - nothing to-do
        }
        if ( isLoadedByParentLoader(bcProvider.getClass()) ) {
            return; // loaded but not by us - nothing to-do
            // NOTE: JRuby handles this correctly as well, adds the BC provider
            // only if ... java.security.Security.getProvider("BC") == null
        }

        final String classLoaderName = bcProvider.getClass().getClassLoader().getClass().getName();
        if ( "org.jruby.util.JRubyClassLoader".equals(classLoaderName) ) {
            log.info("removing 'BC' security provider (likely registered by jruby-openssl)");
        }
        else {
            log.warn("removing 'BC' security provider loaded by class-loader: " + bcProvider.getClass().getClassLoader());
        }
        synchronized(java.security.Security.class) {
            if ( java.security.Security.getProvider("BC") != null ) {
                java.security.Security.removeProvider("BC"); // since we loaded it
            }
        }
    }

    /*
    private void shutdownAbandonedConnectionCleanupThread() {
        final String className = "com.mysql.jdbc.AbandonedConnectionCleanupThread";
        try {
            Class threadClass = Class.forName(className, false, getClassLoader());
            if (threadClass != null) {
                threadClass.getMethod("shutdown").invoke(null);
                log.info("MySQL connection cleanup thread shutdown has been triggered");
            }
        }
        catch (ClassNotFoundException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e);
        }
        catch (NoSuchMethodException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e);
        }
        catch (IllegalAccessException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e);
        }
        catch (InvocationTargetException e) {
            log.info("MySQL connection cleanup thread shutdown failed", e);
        }
    } */

    private boolean isLoadedByParentLoader(final Class<?> clazz) {
        final ClassLoader clazzLoader = clazz.getClassLoader();
        ClassLoader parentLoader = getWebAppLoader().getParent();
        while ( parentLoader != null ) {
            if ( clazzLoader == parentLoader ) return true;
            parentLoader = parentLoader.getParent();
        }
        return false;
    }

    private boolean isLoadedByThisLoader(final Object obj) {
        final ClassLoader classLoader = getWebAppLoader();
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

    private ClassLoader getWebAppLoader() {
        final ClassLoader classLoader = getClassLoader();
        if ( classLoader == null ) {
            throw new IllegalStateException("unexpected state " + getStateName() + " no class-loader");
        }
        return classLoader;
    }

}
