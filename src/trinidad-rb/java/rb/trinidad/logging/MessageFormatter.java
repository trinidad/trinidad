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

import java.util.logging.Formatter;
import java.util.logging.LogRecord;

import static rb.trinidad.logging.LoggingHelpers.*;

/**
 * Console message (record) formatter for Trinidad.
 *
 * @author kares
 */
public class MessageFormatter extends Formatter {

    @Override
    public String format(final LogRecord record) {
        final StringBuilder msg = new StringBuilder( record.getMessage() );
        // since we're going to print Rails.logger logs and they tend
        // to already have the ending "\n" handle such cases nicely :
        if ( isContextLogger( record.getLoggerName() ) ) {
            if ( ! endsWithLineSeparator(msg) ) msg.append(LINE_SEPARATOR);
        }
        else {
            msg.append(LINE_SEPARATOR);
        }
        formatThrown( record.getThrown(), msg );
        return msg.toString();
    }

}
