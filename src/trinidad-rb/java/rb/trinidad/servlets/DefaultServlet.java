/*
 * Copyright (c) 2012 Team Trinidad and contributors http://github.com/trinidad
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

package rb.trinidad.servlets;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;

import org.apache.naming.resources.ProxyDirContext;


/**
 * Tomcat's default resource-serving servlet adapted to accept a "public.root".
 * 
 * <p>
 * This servlet (like it's super class) is intended to be mapped to <em>/</em> !
 * </p>
 * 
 * @author kares
 */
public class DefaultServlet extends org.apache.catalina.servlets.DefaultServlet {

    private transient String publicRoot = null;

    public String getPublicRoot() {
        return this.publicRoot;
    }

    public void setPublicRoot(String publicRoot) {
        if ( publicRoot == null ) publicRoot = "";
        if ( publicRoot.endsWith("/") ) {
            publicRoot = publicRoot.substring(0, publicRoot.length() - 1);
        }
        if ( ! publicRoot.startsWith("/") ) {
            publicRoot = "/" + publicRoot;
        }
        this.publicRoot = publicRoot.equals("/") ? null : publicRoot;
    }
    
    public ProxyDirContext getResources() {
        return this.resources;
    }
    
    @Override
    public void init() throws ServletException {
        super.init();
        String root = getServletConfig().getInitParameter("public.root");
        if (root == null) {
            root = getServletContext().getInitParameter("public.root");
        }
        setPublicRoot( root );
    }
    
    @Override
    protected String getRelativePath(final HttpServletRequest request) {
        // IMPORTANT: DefaultServlet can be mapped to '/' or '/path/*' but always
        // serves resources from the web app root with context rooted paths.
        // i.e. it can not be used to mount the web app root under a sub-path

        // NOTE: all overriding due so we can "/public" prefix here :
        String result = super.getRelativePath(request);
        final String prefix = getPublicRoot();
        if ( prefix != null ) result = prefix + result;
        return result;
    }

    @Override
    protected String getPathPrefix(final HttpServletRequest request) {
        return request.getContextPath();
    }

    /*
    @Override
    public void log(String msg) {
        // log("DefaultServlet.init:  input buffer size=" + input + ", output buffer size=" + output);
        // log("DefaultServlet.serveFile:  contentType='" + contentType + "'");
        // log("DefaultServlet.serveFile:  contentLength=" + contentLength);
        super.log(msg); // getServletContext().log(getServletName() + ": " + msg);
    } */
    
}
