/*
 * Copyright (c) 2013 Team Trinidad and contributors http://github.com/trinidad
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

package rb.trinidad;

import java.io.File;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.jar.JarFile;

import org.apache.catalina.Context;
import org.apache.catalina.Engine;
import org.apache.catalina.Globals;
import org.apache.catalina.Host;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.Server;
import org.apache.catalina.Service;
import org.apache.catalina.connector.Connector;
import org.apache.catalina.core.StandardEngine;
import org.apache.catalina.core.StandardServer;
import org.apache.catalina.core.StandardService;
import org.apache.catalina.startup.Constants;
import org.apache.catalina.startup.Tomcat;
import org.apache.juli.logging.LogFactory;

/**
 * Jerry - Tomcat's little companion.
 *
 * @see org.apache.catalina.startup.Tomcat
 *
 * @author kares
 */
public class Jerry extends Tomcat {

    private static final String SERVICE_NAME = "Tomcat"; // "Trinidad"
    private static final String ENGINE_NAME = SERVICE_NAME;

    public Jerry() {
        port = 3000;
    }

    // TODO: lazy init for the temp dir - only when a JSP is compiled or
    // get temp dir is called we need to create it. This will avoid the
    // need for the baseDir

    public String getBasedir() {
        return basedir;
    }

    public int getPort() {
        return port;
    }

    public String getHostname() {
        return hostname;
    }

    @Override
    public void destroy() throws LifecycleException {
        if ( server != null ) server.destroy(); // super.destroy();
        this.server = null;
        this.service = null;
        this.engine = null;
        this.connector = null;
        this.host = null;
    }

    // ------- Extra customization -------
    // You can tune individual tomcat objects, using internal APIs

    /**
     * Get the default http connector. You can set more
     * parameters - the port is already initialized.
     *
     * Alternatively, you can construct a Connector and set any params,
     * then call addConnector(Connector)
     *
     * @return A connector object that can be customized
     */
    public Connector getConnector() {
        getServer(); // initializes this.service
        if ( connector == null ) {
            connector = new Connector("HTTP/1.1");
            // connector = new Connector("org.apache.coyote.http11.Http11Protocol");
            connector.setPort(port);
            service.addConnector( connector );
        }
        return connector;
    }

    @Override
    public Engine getEngine() {
        if ( engine == null ) {
            final Service service = getService();
            engine = new StandardEngine();
            engine.setName(ENGINE_NAME);
            engine.setDefaultHost(hostname);
            service.setContainer(engine);
        }
        return engine;
    }

    @Override
    public Server getServer() {
        if ( server != null ) return server;

        initBaseDir();

        System.setProperty("catalina.useNaming", "false");

        server = new StandardServer();
        server.setPort( -1 );

        service = new StandardService();
        service.setName(SERVICE_NAME);
        server.addService( service );

        return server;
    }

    public Context addContext(Host host, String contextPath, String contextName,
            String dir) {

        // NOTE: do not silence(host, contextPath); ?

        Context ctx = createContext(host, contextPath);
        ctx.setName(contextName);
        ctx.setPath(contextPath);
        ctx.setDocBase(dir);
        ctx.addLifecycleListener(new Tomcat.FixContextListener()); // REVIEW

        if (host == null) {
            getHost().addChild(ctx);
        } else {
            host.addChild(ctx);
        }
        return ctx;
    }

    @Override
    protected void initBaseDir() {
        final String catalinaHome = System.getProperty(Globals.CATALINA_HOME_PROP);

        if ( basedir == null ) basedir = System.getProperty(Globals.CATALINA_BASE_PROP);
        if ( basedir == null ) basedir = catalinaHome;

        if ( basedir == null ) { // create a temp directory
            final String currentDir = System.getProperty("user.dir");
            // compatibility with previous Trinidad (Tomcat) :
            File homeFile = new File(currentDir + "/tomcat." + port);
            if ( ! homeFile.exists() ) {
                // rails/rack apps usually have a /tmp directory, check the case :
                File appTmpDir = new File(currentDir + "/tmp");
                if ( appTmpDir.exists() && ! currentDir.isEmpty() ) {
                    // some (default) trinidad conventions ... yay :
                    homeFile = new File(appTmpDir + "/trinidad." + port);
                }

                homeFile.mkdir(); // TODO do not makedir the directory - lazy init ?!
            }
            if ( ! homeFile.isAbsolute() ) {
                try {
                    basedir = homeFile.getCanonicalPath();
                } catch (IOException e) {
                    basedir = homeFile.getAbsolutePath();
                }
            }
            else {
                basedir = homeFile.getPath();
            }
        }

        if ( catalinaHome == null ) System.setProperty(Globals.CATALINA_HOME_PROP, basedir);
        System.setProperty(Globals.CATALINA_BASE_PROP, basedir);
    }

    /**
     * Enables JNDI naming which is disabled by default.
     */
    @Override
    public void enableNaming() {
        super.enableNaming();
    }

    @Override
    protected URL getWebappConfigFile(String path, String url) {
        // for Trinidad this will likely return null
        final File docBase = new File(path);
        if ( docBase.isDirectory() ) {
            return getContextXmlFromDir(docBase, url);
        }
        if ( docBase.isFile() ) {
            return getContextXmlFromWar(docBase, url);
        }
        return null;
    }

    private URL getContextXmlFromDir(File docBase, String url) {
        File webAppContextXml = new File(docBase, Constants.ApplicationContextXml);
        if ( webAppContextXml.exists() ) {
            try {
                return webAppContextXml.toURI().toURL();
            }
            catch (MalformedURLException e) {
                logInfo(url, "Unable to determine web application context.xml " + docBase + " : " + e);
            }
        }
        return null;
    }

    private URL getContextXmlFromWar(File docBase, String url) {
        JarFile jar = null;
        try {
            jar = new JarFile(docBase);
            final String contextXml = Constants.ApplicationContextXml;
            if ( jar.getJarEntry(contextXml) != null ) {
                return new URL("jar:" + docBase.toURI().toString() + "!/" + contextXml);
            }
        }
        catch (IOException e) {
            logInfo(url, "Unable to determine web application context.xml " + docBase + " : " + e);
        }
        finally {
            if (jar != null) {
                try { jar.close(); } catch (IOException e) { }
            }
        }
        return null;
    }

    private void logInfo(final String context, final String message) {
        LogFactory.getLog( getLoggerName(context) ).info(message);
    }

    private String getLoggerName(final String context) {
        StringBuilder loggerName = new StringBuilder(
            "org.apache.catalina.core.ContainerBase.[default].["
        );
        loggerName.append( getHost().getName() );
        loggerName.append("].[").append(context).append("]");
        return loggerName.toString();
    }

}
