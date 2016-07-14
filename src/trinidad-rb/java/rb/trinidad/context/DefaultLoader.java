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

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.security.Provider;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;
import java.util.Timer;

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

        getClassLoaderBang().setJarPath(null); // super set it to "/WEB-INF/lib"

        getContextBang().addLifecycleListener(contextListener = new ContextListener());
    }

    @Override
    protected void stopInternal() throws LifecycleException {
        if ( contextListener != null ) {
            getContextBang().removeLifecycleListener(contextListener);
            contextListener = null;
        }

        Collection<Ruby> managedRuntimes; // only 1 for threadsafe!
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
            if ( jrubyLoaders != null ) performJDBCDriversCleanup(jrubyLoaders);
            if ( jrubyLoaders != null ) removeSecurityProviderForOpenSSL(jrubyLoaders);
            mendContextLoaderForTimeoutWorkerThreads();
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
            if ( apps == null ) return null; // e.g. in case of initialization error
            final Collection<Ruby> runtimes = new LinkedHashSet<Ruby>(apps.size());
            for ( Object app : apps ) { // most likely only one (threadsafe!)
                Object runtime = app.getClass().getMethod("getRuntime").invoke(app);
                runtimes.add( (Ruby) runtime );
            }

            if ( runtimes.isEmpty() ) {
                log.info("No managed runtimes found for context: " + getContainer());
            }
            else {
                log.debug("Found " + runtimes.size() + " managed runtimes for context: " + getContainer());
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
            final Throwable target = e.getTargetException();
            if ( target instanceof UnsupportedOperationException ) {
                log.debug("Getting managed runtimes is not supported", target);
            }
            else {
                log.info("Failed getting managed runtimes from rack.factory", target);
            }
        }
        return null;
    }

    private WebappClassLoader getClassLoaderBang() {
        final ClassLoader classLoader = getClassLoader();
        if ( classLoader == null ) {
            throw new IllegalStateException("unexpected state " + getStateName() + " no class-loader");
        }
        return (WebappClassLoader) classLoader;
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

    @SuppressWarnings("element-type-mismatch")
    private void removeSecurityProviderForOpenSSL(final Collection<JRubyClassLoader> appLoaders) {
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
            if ( java.security.Security.getProvider("BC") == bcProvider ) {
                java.security.Security.removeProvider("BC"); // since we loaded it
            }
        }
    }

    private void mendContextLoaderForTimeoutWorkerThreads() {
        //List<Thread> workerThreads = findThreads("JRubyTimeoutWorker-", null);
        //if ( workerThreads.isEmpty() ) {
            // JRuby 9000 changing daemon thread naming convention
            // e.g. "JRubyFiber-1" -> "Ruby-2-Fiber-1" ('2' is runtime number)
            List<Thread> workerThreads = findThreads("TimeoutWorker-", null);
        //}
        for ( int i=0; i<workerThreads.size(); i++ ) {
            final Thread worker = workerThreads.get(i);
            final String name = worker.getName();  // make sure it's from JRuby
            if ( name == null || name.indexOf("Ruby") == -1 ) continue;
            if ( worker.getContextClassLoader() == getClassLoader() ) {
                worker.setContextClassLoader( getClassLoader().getParent() );
            }
        }
    }

    private static Class<?> getTimeoutLibraryImpl() throws ClassNotFoundException {
        final String version = org.jruby.runtime.Constants.VERSION.substring(0, 3);
        final String className;
        if ( version.compareTo("1.7") < 0 ) className = "org.jruby.ext.Timeout";
        else className = "org.jruby.ext.timeout.Timeout";
        return Class.forName(className, true, Ruby.getClassLoader());
    }

    private void performJDBCDriversCleanup(final Collection<JRubyClassLoader> appLoaders) {
        // TODO unregister with DriverManager

        performMySQLDriverCleanup(appLoaders);
        performMariaDBDriverCleanup(appLoaders);
        performPostgreSQLDriverCleanup(appLoaders);
    }

    private void performMySQLDriverCleanup(final Collection<JRubyClassLoader> appLoaders) {
        List<Thread> cleanupThreads = findAbandonedConnectionCleanupThreads();
        if ( cleanupThreads != null && ! cleanupThreads.isEmpty() ) {
            shutdownMySQLAbandonedConnectionCleanupThreads(appLoaders);
            /*
            for ( Thread cleanupThread : cleanupThreads ) {
                ClassLoader threadLoader = cleanupThread.getContextClassLoader();
                // it's context class-loader will be likely our WebappClassLoader instance
                if ( ( threadLoader == getClassLoader() || appLoaders.contains( threadLoader ) )
                        && cleanupThread.isAlive() ) {
                    log.debug("Matched running MySQL connection cleanup thread: " + cleanupThread);
                    shutdownMySQLAbandonedConnectionCleanupThread(threadLoader);
                }
            } */
        }
    }

    @SuppressWarnings("unchecked")
    private void performMariaDBDriverCleanup(final Collection<JRubyClassLoader> appLoaders) {
        final String className = "org.mariadb.jdbc.MySQLStatement";
        for ( ClassLoader appLoader : appLoaders ) {
            try { // will be loaded by JRuby's loader if `require 'jdbc/mariadb'
                Class statementClass = getClassLoadedBy(className, appLoader, true);
                if ( statementClass != null ) {
                    // private static volatile Timer timer;
                    Field timerField = statementClass.getDeclaredField("timer");
                    timerField.setAccessible(true);
                    final Timer timer = (Timer) timerField.get(null);
                    if ( timer != null ) {
                        timer.purge();
                        log.info("MariaDB timeout timer has been purged");
                    }
                }
            }
            catch (NoSuchFieldException e) {
                log.info("MariaDB driver timeout timer purging failed: " + e);
            }
            catch (IllegalAccessException e) {
                log.info("MariaDB driver timeout timer purging failed: " + e);
            }
        }
    }

    @SuppressWarnings("unchecked")
    private void performPostgreSQLDriverCleanup(final Collection<JRubyClassLoader> appLoaders) {
        final String className = "org.postgresql.Driver"; boolean oldCleanup = false;
        for ( ClassLoader appLoader : appLoaders ) {
            try { // will be loaded by JRuby if `require 'jdbc/postgres'
                Class driverClass = getClassLoadedBy(className, appLoader, true);
                if ( driverClass != null ) {
                    boolean getSharedTimer = false;
                    try { // org.postgresql.util.SharedTimer sharedTimer;
                        Object sharedTimer = driverClass.getMethod("getSharedTimer").invoke(null);
                        getSharedTimer = true;
                        sharedTimer.getClass().getMethod("releaseTimer").invoke(sharedTimer);
                    }
                    catch (NoSuchMethodException e) {
                        if ( ! getSharedTimer ) { oldCleanup = true; break; }
                    }
                }
            }
            catch (IllegalAccessException e) {
                log.info("PostgreSQL driver shared timer release failed: " + e);
            }
            catch (InvocationTargetException e) {
                log.info("PostgreSQL driver shared timer release failed", e.getTargetException());
            }
        }
        if ( oldCleanup ) performOldPostgreSQLDriverCleanup(className, appLoaders);
    }

    @SuppressWarnings("unchecked")
    private void performOldPostgreSQLDriverCleanup(final String className,
        final Collection<JRubyClassLoader> appLoaders) {
        // cleanup started java.util.Timer-s which is fixed on some of 9.3 :
        // https://github.com/pgjdbc/pgjdbc/commit/ac0949542e898da884f7cc213103983a856cab83
        for ( ClassLoader appLoader : appLoaders ) {
            try { // will be loaded by JRuby if `require 'jdbc/postgres'
                Class driverClass = getClassLoadedBy(className, appLoader, true);
                if ( driverClass != null ) {
                    try {
                        driverClass.getMethod("purgeTimerTasks").invoke(null);
                    }
                    catch (NoSuchMethodException e) { // try the old way
                        // private static Timer cancelTimer = null;
                        Field cancelTimerField = driverClass.getDeclaredField("cancelTimer");
                        cancelTimerField.setAccessible(true);
                        final Timer cancelTimer = (Timer) cancelTimerField.get(null);
                        if ( cancelTimer != null ) {
                            cancelTimer.purge();
                            log.info("PostgreSQL driver cancel timer has been purged");
                        }
                    }
                }
            }
            catch (NoSuchFieldException e) {
                log.info("PostgreSQL driver cancel timer purging failed: " + e);
            }
            catch (IllegalAccessException e) {
                log.info("PostgreSQL driver cancel timer purging failed: " + e);
            }
            catch (InvocationTargetException e) {
                log.info("PostgreSQL driver cancel timer purging failed", e.getTargetException());
            }
        }
    }

    private static List<Thread> findAbandonedConnectionCleanupThreads() {
        // thread's name: "Abandoned connection cleanup thread"
        return findThreads("Abandoned connection cleanup thread", null);
    }

    @SuppressWarnings("unchecked")
    private void shutdownMySQLAbandonedConnectionCleanupThreads(final Collection<JRubyClassLoader> appLoaders) {
        final String className = "com.mysql.jdbc.AbandonedConnectionCleanupThread";

        for ( ClassLoader appLoader : appLoaders ) {
            try {
                // will be loaded by JRuby if `require 'jdbc/mysql'; Jdbc::MySQL.load_driver`
                Class threadClass = getClassLoadedBy(className, appLoader, false);
                    // Class.forName(className, false, appLoader);
                if ( threadClass != null ) {
                    if ( threadClass.getClassLoader() == appLoader
                        || threadClass.getClassLoader() == getClassLoader() ) {
                        threadClass.getMethod("shutdown").invoke(null); // stop's the thread
                        log.info("MySQL connection cleanup thread shutdown has been triggered");
                    }
                }
            }
            //catch (ClassNotFoundException e) {
            //    log.debug("MySQL connection cleanup thread not present", e);
            //}
            catch (NoSuchMethodException e) {
                log.info("MySQL connection cleanup thread shutdown failed: " + e);
            }
            catch (IllegalAccessException e) {
                log.info("MySQL connection cleanup thread shutdown failed: " + e);
            }
            catch (InvocationTargetException e) {
                log.info("MySQL connection cleanup thread shutdown failed", e.getTargetException());
            }
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

    /*
    private boolean isLoadedByThisLoader(final Object obj) {
        final ClassLoader classLoader = getClassLoaderBang();
        return isLoadedBy(obj, classLoader, false);
    } */

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

    private static List<Thread> findThreads(final String namePart,
        final Collection<ClassLoader> contextLoader) {

        final Thread[] allThreads = allThreads();

        final List<Thread> threads = new LinkedList<Thread>();

        for ( int i=0; i<allThreads.length; i++ ) {
            final Thread thread = allThreads[i];
            if ( thread == null ) continue;

            if ( namePart != null ) {
                if ( thread.getName().indexOf(namePart) >= 0 ) threads.add(thread);
            }
            if ( contextLoader != null ) {
                if ( contextLoader.contains( thread.getContextClassLoader() ) ) {
                    if ( namePart == null ) threads.add(thread);
                }
                else {
                    threads.remove(thread);
                }
            }

            if ( namePart == null && contextLoader == null ) threads.add(thread);
        }
        return threads;
    }

    private static Thread[] allThreads() {
        // Get the current thread group
        ThreadGroup group = Thread.currentThread().getThreadGroup();
        // Find the root thread group
        try {
            while ( group.getParent() != null ) group = group.getParent();
        }
        catch (SecurityException se) {
            String msg = sm.getString("webappClassLoader.getThreadGroupError", group.getName());
            if (log.isDebugEnabled()) {
                log.debug(msg, se);
            }
            else {
                log.warn(msg);
            }
        }

        int threadCountGuess = group.activeCount() + 50;
        Thread[] allThreads = new Thread[threadCountGuess];
        int threadCountActual = group.enumerate(allThreads);
        // Make sure we don't miss any threads
        while ( threadCountActual == threadCountGuess ) {
            threadCountGuess *= 2;
            allThreads = new Thread[threadCountGuess];
            // Note tg.enumerate(Thread[]) silently ignores any threads that
            // can't fit into the array
            threadCountActual = group.enumerate(allThreads);
        }

        return allThreads;
    }

    @SuppressWarnings("unchecked")
    private static Collection<Class<?>> loadedClasses(final ClassLoader classLoader) {
        try {
            final Field classesField = ClassLoader.class.getDeclaredField("classes");
            classesField.setAccessible(true);
            // private final Vector<Class<?>> classes = new Vector<>();
            return (Collection<Class<?>>) classesField.get(classLoader);
        }
        catch (NoSuchFieldException e) {
            log.info("can not access classes field for " + classLoader + " ", e);
        }
        catch (IllegalAccessException e) {
            log.info("can not access classes field for " + classLoader + " ", e);
        }
        return null;
    }

    private static Class<?> getClassLoadedBy(final String name,
        final ClassLoader classLoader, final boolean loadedOnly) {
        try {
            Collection<Class<?>> loaded = loadedClasses(classLoader);
            if ( loaded != null ) {
                Class[] loadedClasses = loaded.toArray(new Class[loaded.size()]);
                for ( Class loadedClass : loadedClasses ) {
                    if ( name.equals(loadedClass.getName()) ) return loadedClass;
                }
                return null;
            }
            return loadedOnly ? null : Class.forName(name, false, classLoader);
        }
        catch (ClassNotFoundException e) { return null; }
    }

    private class ContextListener implements LifecycleListener {

        @Override
        public void lifecycleEvent(LifecycleEvent event) {
            if ( event.getType() == (Object) Lifecycle.STOP_EVENT ) {
                DefaultLoader.this.contextStopEvent();
            }
        }

    }

}
