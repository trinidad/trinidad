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
import java.net.JarURLConnection;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.URLConnection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;
import java.util.StringTokenizer;
import javax.servlet.ServletContext;

import org.apache.juli.logging.Log;

import org.apache.tomcat.JarScannerCallback;
import org.apache.tomcat.util.file.Matcher;
import org.apache.tomcat.util.res.StringManager;
import org.apache.tomcat.util.scan.Constants;
import org.apache.tomcat.util.scan.StandardJarScanner;

public class DefaultJarScanner extends StandardJarScanner {

    private static final Log log = org.apache.juli.logging.LogFactory.getLog(
            org.apache.tomcat.util.scan.StandardJarScanner.class
    );

    private static final Set<String> defaultJarsToSkip = new HashSet<String>();

    /**
     * The string resources for this package.
     */
    private static final StringManager sm =
        StringManager.getManager(Constants.Package);

    static {
        String jarList = System.getProperty(Constants.SKIP_JARS_PROPERTY);
        if (jarList != null) {
            StringTokenizer tokenizer = new StringTokenizer(jarList, ",");
            while (tokenizer.hasMoreElements()) {
                defaultJarsToSkip.add(tokenizer.nextToken());
            }
        }
    }

    /**
     * Controls the classpath scanning extension.
     */
    //private boolean scanClassPath = true;

    /**
     * Controls the testing all files to see of they are JAR files extension.
     */
    //private boolean scanAllFiles = false;

    /**
     * Controls the testing all directories to see of they are exploded JAR
     * files extension.
     */
    //private boolean scanAllDirectories = false;

    /**
     * Controls the testing of the bootstrap classpath which consists of the
     * runtime classes provided by the JVM and any installed system extensions.
     */
    //private boolean scanBootstrapClassPath = false;

    /**
     * Scan the provided ServletContext and classloader for JAR files. Each JAR
     * file found will be passed to the callback handler to be processed.
     *
     * @param context       The ServletContext - used to locate and access
     *                      WEB-INF/lib
     * @param classloader   The classloader - used to access JARs not in
     *                      WEB-INF/lib
     * @param callback      The handler to process any JARs found
     * @param jarsToSkip    List of JARs to ignore. If this list is null, a
     *                      default list will be read from the system property
     *                      defined by {@link Constants#SKIP_JARS_PROPERTY}
     */
    @Override
    public void scan(ServletContext context, ClassLoader classloader,
            JarScannerCallback callback, Set<String> jarsToSkip) {

        if (log.isTraceEnabled()) {
            log.trace(sm.getString("jarScan.webinflibStart"));
        }

        Set<String> ignoredJars;
        if (jarsToSkip == null) {
            ignoredJars = defaultJarsToSkip;
        } else {
            ignoredJars = jarsToSkip;
        }
        Set<String[]> ignoredJarsTokens = new HashSet<String[]>();
        for (String pattern: ignoredJars) {
            ignoredJarsTokens.add(Matcher.tokenizePathAsArray(pattern));
        }

        // Scan WEB-INF/lib
        Set<String> dirList = context.getResourcePaths(Constants.WEB_INF_LIB);
        if (dirList != null) {
            Iterator<String> it = dirList.iterator();
            while (it.hasNext()) {
                String path = it.next();
                if (path.endsWith(Constants.JAR_EXT) &&
                    !Matcher.matchPath(ignoredJarsTokens,
                        path.substring(path.lastIndexOf('/')+1))) {
                    // Need to scan this JAR
                    if (log.isDebugEnabled()) {
                        log.debug(sm.getString("jarScan.webinflibJarScan", path));
                    }
                    URL url = null;
                    try {
                        // File URLs are always faster to work with so use them
                        // if available.
                        String realPath = context.getRealPath(path);
                        if (realPath == null) {
                            url = context.getResource(path);
                        } else {
                            url = (new File(realPath)).toURI().toURL();
                        }
                        process(callback, url);
                    } catch (IOException e) {
                        log.warn(sm.getString("jarScan.webinflibFail", url), e);
                    }
                } else {
                    if (log.isTraceEnabled()) {
                        log.trace(sm.getString("jarScan.webinflibJarNoScan", path));
                    }
                }
            }
        }

        // Scan the classpath
        if ( isScanClassPath() && classloader != null ) {
            if (log.isTraceEnabled()) {
                log.trace(sm.getString("jarScan.classloaderStart"));
            }

            ClassLoader loader = classloader;

            ClassLoader stopLoader = null;
            if ( ! isScanBootstrapClassPath() ) {
                // Stop when we reach the bootstrap class loader
                stopLoader = ClassLoader.getSystemClassLoader().getParent();
            }

            while (loader != null && loader != stopLoader) {
                if (loader instanceof URLClassLoader) {
                    URL[] urls = ((URLClassLoader) loader).getURLs();
                    for (int i=0; i<urls.length; i++) {
                        // Extract the jarName if there is one to be found
                        String jarName = getJarName(urls[i]);

                        // Skip JARs known not to be interesting and JARs
                        // in WEB-INF/lib we have already scanned
                        if (jarName != null &&
                            !(Matcher.matchPath(ignoredJarsTokens, jarName) ||
                                urls[i].toString().contains(
                                        Constants.WEB_INF_LIB + jarName))) {
                            if (log.isDebugEnabled()) {
                                log.debug(sm.getString("jarScan.classloaderJarScan", urls[i]));
                            }
                            try {
                                process(callback, urls[i]);
                            } catch (IOException ioe) {
                                log.warn(sm.getString(
                                        "jarScan.classloaderFail",urls[i]), ioe);
                            }
                        } else {
                            if (log.isTraceEnabled()) {
                                log.trace(sm.getString("jarScan.classloaderJarNoScan", urls[i]));
                            }
                        }
                    }
                }
                loader = loader.getParent();
            }

        }
    }

    /*
     * Scan a URL for JARs with the optional extensions to look at all files
     * and all directories.
     */
    private void process(JarScannerCallback callback, URL url)
            throws IOException {

        if (log.isTraceEnabled()) {
            log.trace(sm.getString("jarScan.jarUrlStart", url));
        }

        URLConnection conn = url.openConnection();
        if (conn instanceof JarURLConnection) {
            callback.scan((JarURLConnection) conn);
        } else {
            String urlStr = url.toString();
            if (urlStr.startsWith("file:") || urlStr.startsWith("jndi:") ||
                    urlStr.startsWith("http:") || urlStr.startsWith("https:")) {
                if (urlStr.endsWith(Constants.JAR_EXT)) {
                    URL jarURL = new URL("jar:" + urlStr + "!/");
                    callback.scan((JarURLConnection) jarURL.openConnection());
                } else {
                    File f;
                    try {
                        f = new File(url.toURI());
                        if ( f.isFile() && isScanAllFiles() ) {
                            // Treat this file as a JAR
                            URL jarURL = new URL("jar:" + urlStr + "!/");
                            callback.scan((JarURLConnection) jarURL.openConnection());
                        } else if ( f.isDirectory() && isScanAllDirectories() ) {
                            File metainf = new File(f.getAbsoluteFile() + File.separator + "META-INF");
                            if (metainf.isDirectory()) {
                                callback.scan(f);
                            }
                        }
                    } catch (URISyntaxException e) {
                        // Wrap the exception and re-throw
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
