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

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Field;
import java.net.JarURLConnection;
import java.net.MalformedURLException;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.URLConnection;
import java.util.HashSet;
import java.util.Set;
import java.util.StringTokenizer;
import javax.servlet.ServletContext;

import org.apache.juli.logging.Log;

import org.apache.catalina.Context;
import org.apache.catalina.Loader;
import org.apache.catalina.core.StandardContext;
import org.apache.tomcat.JarScannerCallback;
import org.apache.tomcat.util.file.Matcher;
import org.apache.tomcat.util.scan.Constants;
import org.apache.tomcat.util.scan.StandardJarScanner;

/**
 * Default "faster" jar scanner - typically saves a few 10s of millis on start.
 *
 * NOTE: avoids {@link org.apache.tomcat.websocket.server.WsSci} being registered by default!
 *
 * @author kares
 */
public class DefaultJarScanner extends StandardJarScanner {

    private static final Log log = org.apache.juli.logging.LogFactory.getLog(DefaultJarScanner.class);

    private final Context context;

    public DefaultJarScanner(final Context context) {
        this.context = ( context instanceof StandardContext ) ? context : null;
        scanClassPathLoaderOnly = this.context != null;
        // test all files to see of they are JAR files extension :
        setScanAllFiles(true);
        // test all directories to see of they are exploded JAR files extension :
        setScanAllDirectories(false);
    }

    private static final Set<String> defaultJarsToSkip;

    static {
        Set<String> jarsToSkip;
        try {
            Field defaultJarsToSkipField = StandardJarScanner.class.getDeclaredField("defaultJarsToSkip");
            defaultJarsToSkipField.setAccessible(true);
            @SuppressWarnings("unchecked")
            Set<String> _jarsToSkip = (Set<String>) defaultJarsToSkipField.get(null);
            jarsToSkip = _jarsToSkip;
        }
        catch (Exception e) {
            log.info("Failed accessing defaultJarsToSkip field " + e);

            jarsToSkip = new HashSet<String>(4, 1);
            String jarList = System.getProperty(Constants.SKIP_JARS_PROPERTY);
            if ( jarList != null ) {
                StringTokenizer tokenizer = new StringTokenizer(jarList, ",");
                while ( tokenizer.hasMoreElements() ) {
                    final String token = tokenizer.nextToken().trim();
                    if ( token.length() > 0 ) jarsToSkip.add(token);
                }
            }
        }
        defaultJarsToSkip = jarsToSkip;
        defaultJarsToSkip.add("jruby-rack*.jar"); // jruby-rack-1.1.15-SNAPSHOT.jar
        // for potential warbled .wars :
        defaultJarsToSkip.add("jruby-core*.jar"); // jruby-core-complete-1.7.12.jar
        defaultJarsToSkip.add("jruby-stdlib*.jar"); // jruby-stdlib-complete-1.7.12.jar
    }

    static Set<String> getDefaultJarsToSkip() {
        return defaultJarsToSkip;
    }

    private boolean scanClassPathLoaderOnly;

    public boolean isScanClassPathLoaderOnly() {
        return scanClassPathLoaderOnly;
    }

    public void setScanClassPathLoaderOnly(boolean scanClassPathLoaderOnly) {
        this.scanClassPathLoaderOnly = scanClassPathLoaderOnly;
    }

    /**
     * Controls the classpath scanning extension.
     */
    @Override
    public void setScanClassPath(boolean scanClassPath) {
        super.setScanClassPath(scanClassPath); // true by default
        scanClassPathLoaderOnly = false; // disable our "fast" scan
    }

    @Override
    public void scan(final ServletContext context, final ClassLoader classLoader,
        final JarScannerCallback callback, Set<String> jarsToSkip) {
        final long millis = System.currentTimeMillis();

        Loader contextLoader = null;
        if ( this.context != null && this.context.getServletContext() == context ) {
            Loader loader = this.context.getLoader();
            if ( loader != null && loader.getClassLoader() == classLoader ) {
                contextLoader = loader;
            }
        }

        if ( contextLoader == null || Boolean.getBoolean("scan.super") ) {
            super.scan(context, classLoader, callback, jarsToSkip);
            if (log.isDebugEnabled()) {
                log.debug("Scanning for JARs (standard) completed in " + (System.currentTimeMillis() - millis) + " millis");
            }
            return;
        }

        if (log.isTraceEnabled()) log.trace("Scanning application for JARs");

        final Set<String> ignoredJars = jarsToSkip == null ? defaultJarsToSkip : jarsToSkip;

        // a better version of scan-ing "WEB-INF/lib" :
        final String[] dirList = contextLoader.findRepositories();
        if ( dirList != null ) {
            for ( int i=0; i<dirList.length; i++ ) {
                final String path = dirList[i];
                if ( path.endsWith(Constants.JAR_EXT) &&
                    !Matcher.matchName( ignoredJars, path.substring(path.lastIndexOf('/') + 1) ) ) {
                    // Need to scan this JAR
                    if (log.isDebugEnabled()) log.debug("Scanning application JAR ["+ path +"]");
                    URL url = null;
                    try {
                        try {
                            if ( path.indexOf(':') > 1 ) url = new URL(path);
                        }
                        catch (MalformedURLException ignore) { /* no protocol */ }
                        if ( url == null ) {
                            String realPath = context.getRealPath(path);
                            if (realPath == null) {
                                url = context.getResource(path);
                            } else {
                                url = (new File(realPath)).toURI().toURL();
                            }
                        }
                        process(callback, url);
                    }
                    catch (IOException e) {
                        log.warn("Failed to scan aplication JAR ["+ url +"]", e);
                    }
                }
                else {
                    if (log.isTraceEnabled()) log.trace("Not scanning application JAR ["+ path +"]");
                }
            }
        }

        // Scan the classpath
        if ( isScanClassPath() && classLoader != null ) {
            if (log.isTraceEnabled()) log.trace("Scanning for JARs in classpath");

            ClassLoader loader = classLoader;

            ClassLoader stopLoader = null;
            if ( ! isScanBootstrapClassPath() ) {
                // Stop when we reach the bootstrap class loader
                stopLoader = ClassLoader.getSystemClassLoader().getParent();
            }

            // TODO maybe look into the JRubyClassLoader which is the child of loader

            while ( loader != null && loader != stopLoader ) {
                if (loader instanceof URLClassLoader) {
                    final URL[] urls = ((URLClassLoader) loader).getURLs();
                    for (int i=0; i<urls.length; i++) {
                        // Extract the jarName if there is one to be found
                        String jarName = getJarName(urls[i]);
                        // Skip JARs known not to be interesting and JARs
                        // in WEB-INF/lib we have already scanned
                        if ( jarName != null &&
                            ! ( Matcher.matchName(ignoredJars, jarName) ||
                                contains( urls[i].toString(), dirList ) ) ) {
                            if (log.isDebugEnabled()) {
                                log.debug("Scanning JAR ["+ urls[i] + " from classpath");
                            }
                            try {
                                process(callback, urls[i]);
                            } catch (IOException ioe) {
                                log.warn("Failed to scan ["+ urls[i] +"] from classpath", ioe);
                            }
                        } else {
                            if (log.isTraceEnabled()) {
                                log.trace("Not scanning JAR ["+ urls[i] +"] from classpath");
                            }
                        }
                    }
                }
                loader = loader.getParent(); if ( scanClassPathLoaderOnly ) break;
            }

        }

        if (log.isDebugEnabled()) {
            log.debug("Scanning for JARs (default) completed in " + (System.currentTimeMillis() - millis) + " millis");
        }
    }

    private static boolean contains(final String path, final String[] fullPaths) {
        if ( fullPaths != null ) {
            for ( int i=0; i<fullPaths.length; i++ ) {
                if ( path.contains(fullPaths[i]) ) return true;
            }
        }
        return false;
    }

    /*
     * Scan a URL for JARs with the optional extensions to look at all files
     * and all directories.
     */
    private void process(final JarScannerCallback callback, final URL url) throws IOException {
        //if (log.isTraceEnabled()) log.trace("Scanning JAR at URL ["+ url +"]");
        final URLConnection urlConnection = url.openConnection();
        if (urlConnection instanceof JarURLConnection) {
            callback.scan((JarURLConnection) urlConnection);
        } else {
            final String urlStr = url.toString();
            if ( urlStr.startsWith("file:") || urlStr.startsWith("jndi:") ||
                 urlStr.startsWith("http:") || urlStr.startsWith("https:") ) {
                if (urlStr.endsWith(Constants.JAR_EXT)) {
                    URL jarURL = new URL("jar:" + urlStr + "!/");
                    callback.scan((JarURLConnection) jarURL.openConnection());
                }
                else {
                    try {
                        final File file = new File(url.toURI());
                        if ( isScanAllFiles() && file.isFile() ) {
                            // Treat this file as a JAR
                            URL jarURL = new URL("jar:" + urlStr + "!/");
                            callback.scan((JarURLConnection) jarURL.openConnection());
                        } else if ( isScanAllDirectories() && file.isDirectory() ) {
                            File metainf = new File(file.getAbsoluteFile() + File.separator + "META-INF");
                            if ( metainf.isDirectory() ) callback.scan(file);
                        }
                    }
                    catch (URISyntaxException e) {
                        throw new IOException(e);
                    }
                }
            }
        }

    }

    /*
     * Extract the JAR name, if present, from a URL
     */
    private String getJarName(URL url) {

        String name = null;

        String path = url.getPath();
        int end = path.indexOf(Constants.JAR_EXT);
        if (end != -1) {
            int start = path.lastIndexOf('/', end);
            name = path.substring(start + 1, end + 4);
        } else if (isScanAllDirectories()){
            int start = path.lastIndexOf('/');
            name = path.substring(start + 1);
        }

        return name;
    }

}
