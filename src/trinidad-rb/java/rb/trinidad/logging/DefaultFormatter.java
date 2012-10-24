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

package rb.trinidad.logging;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.text.DateFormat;
import java.text.FieldPosition;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.TimeZone;
import java.util.logging.Formatter;
import java.util.logging.LogRecord;

/**
 * Default logging record formatter for Trinidad.
 * 
 * @author kares
 */
public class DefaultFormatter extends Formatter {

    private static final String LINE_SEP = System.getProperty("line.separator");

    private final FieldPosition dummyPosition;
    
    {
        FieldPosition fieldPosition;
        try {
            Class klass = Class.forName("java.text.DontCareFieldPosition");
            Field instance = klass.getDeclaredField("INSTANCE");
            instance.setAccessible(true);
            fieldPosition = (FieldPosition) instance.get(null);
        } 
        catch (Exception e) {
            fieldPosition = new FieldPosition(0);
        }
        dummyPosition = fieldPosition;
    }
    
    private final DateFormat dateFormat;

    public DefaultFormatter(String format) {
        this( format != null ? new SimpleDateFormat(format) : new SimpleDateFormat() );
    }
    
    public DefaultFormatter(String format, String timeZone) {
        this( format );
        if ( timeZone != null ) {
            dateFormat.setTimeZone( TimeZone.getTimeZone(timeZone) );
        }
    }

    public DefaultFormatter(String format, int timeZoneOffset) {
        this( format );
        String[] timeZones = TimeZone.getAvailableIDs(timeZoneOffset);
        if ( timeZones.length > 0 ) {
            dateFormat.setTimeZone( TimeZone.getTimeZone(timeZones[0]) );
        }
    }
    
    public DefaultFormatter(String format, Calendar calendar) {
        this( format );
        if ( calendar != null ) {
            dateFormat.setCalendar( calendar );
        }
    }
    
    public DefaultFormatter(DateFormat dateFormat) {
        if ( dateFormat == null ) {
            throw new IllegalArgumentException("no format given");
        }
        this.dateFormat = dateFormat;
    }

    public DateFormat getDateFormat() {
        return dateFormat;
    }
    
    /*
      def format(record)
        timestamp = @format.synchronized do 
          @format.format JDate.new(record.millis)
        end
        level = record.level.name
        message = formatMessage(record)

        out = "#{timestamp} #{level}: #{message}"
        out << formatThrown(record).to_s
        (lns = "\n") == out[-1, 1] ? out : out << lns
      end
     */
    @Override
    public String format(final LogRecord record) {
        String message = record.getMessage();
        StringBuffer msg = new StringBuffer(32 + 2 + 7 + 1 + message.length());
        synchronized(dateFormat) {
            Date millis = new Date(record.getMillis());
            dateFormat.format(millis, msg, dummyPosition);
        }
        msg.append(' ').append(record.getLevel().getName()).append(':'); // WARNING:
        msg.append(' ').append(formatMessage(record)); // message
        if ( ! endsWithLineSep(msg) ) msg.append(LINE_SEP);
        final String thrown = formatThrown(record);
        if ( thrown != null ) msg.append(thrown);
        return msg.toString();
    }
    
    protected String formatThrown(final LogRecord record) {
        final Throwable thrown = record.getThrown();
        if ( thrown != null ) {
            StringWriter stringWriter = new StringWriter(1024);
            PrintWriter printWriter = new PrintWriter(stringWriter);
            thrown.printStackTrace(printWriter);
            printWriter.println();
            printWriter.close();
            return stringWriter.toString();
        }
        return null;
    }
    
    private static boolean endsWithLineSep(StringBuffer msg) {
        final int len = msg.length();
        if ( LINE_SEP != null && len > LINE_SEP.length() ) {
            final int end = len - LINE_SEP.length();
            return msg.substring(end).equals(LINE_SEP);
        }
        return false;
    }
    
}
