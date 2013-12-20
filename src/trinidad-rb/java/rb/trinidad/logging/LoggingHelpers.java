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

package rb.trinidad.logging;

import java.io.PrintWriter;
import java.io.StringWriter;

/**
 * Logging helpers.
 *
 * @author kares
 */
public abstract class LoggingHelpers {

    public static boolean isContextLogger(final String logger) {
        if ( logger == null ) return false;
        if ( ! logger.startsWith("org.apache.catalina.core.ContainerBase.") ) return false;
        // e.g. org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]
        // or org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[default]
        final int end = logger.length() - 1;
        if ( logger.charAt(end) != ']' ) return false;
        final int i = logger.lastIndexOf('[') + 1; if ( i <= 0 ) return false;
        return true;
    }

    public static String getContextName(final String logger) {
        if ( logger == null ) return null;
        if ( ! logger.startsWith("org.apache.catalina.core.ContainerBase.") ) return null;
        // e.g. org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]
        // or org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[default]
        final int end = logger.length() - 1;
        if ( logger.charAt(end) != ']' ) return null;
        final int i = logger.lastIndexOf('[') + 1; if ( i <= 0 ) return null;
        return logger.substring(i, end);
    }

    public static CharSequence formatThrown(final Throwable thrown) {
        if ( thrown == null ) return null;
        final StringBuilder buffer = new StringBuilder();
        formatThrown(thrown, buffer);
        return buffer;
    }

    public static void formatThrown(final Throwable thrown, final StringBuilder buffer) {
        if ( thrown == null ) return;
        StringWriter stringWriter = new StringWriter(512);
        PrintWriter printWriter = new PrintWriter(stringWriter);
        thrown.printStackTrace(printWriter);
        printWriter.println();
        printWriter.close();
        buffer.append( stringWriter.getBuffer() );
    }

    static final String LINE_SEPARATOR = System.getProperty("line.separator");

    static boolean endsWithLineSeparator(final CharSequence msg) {
        final int len = msg.length();
        final String ls = LINE_SEPARATOR;
        if ( ls != null && len > ls.length() ) {
            final int end = len - ls.length();
            return ls.equals( msg.subSequence(end, len) );
        }
        return false;
    }

}
