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

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.lang.reflect.Field;
import java.nio.channels.FileChannel;


/**
 * FileHandler improvements for logging into a file (with JUL).
 * 
 * @author kares
 */
public class FileHandler extends org.apache.juli.FileHandler {
    
    private static final Field directoryField;
    private static final Field prefixField;
    private static final Field suffixField;
    private static final Field rotatableField;
    private static final Field bufferSizeField;
    // current date string e.g. "2012-09-24"
    private static final Field dateField; // FileHandler impl internals
    
    static {
        try {
            Class<?> klass = org.apache.juli.FileHandler.class;
            directoryField = klass.getDeclaredField("directory");
            directoryField.setAccessible(true);
            prefixField = klass.getDeclaredField("prefix");
            prefixField.setAccessible(true);
            suffixField = klass.getDeclaredField("suffix");
            suffixField.setAccessible(true);
            rotatableField = klass.getDeclaredField("rotatable");
            rotatableField.setAccessible(true);
            bufferSizeField = klass.getDeclaredField("bufferSize");
            bufferSizeField.setAccessible(true);
            dateField = // FileHandler impl internals
                klass.getDeclaredField("date");
            dateField.setAccessible(true);
        }
        catch (NoSuchFieldException e) {
            throw new RuntimeException(e);
        }
    }
    
    public FileHandler() {
        super();
    }
    
    public FileHandler(String directory, String prefix, String suffix) {
        super(directory, prefix, suffix);
        setField(dateField, null); // self._date = nil
    }
    
    @Override
    protected void openWriter() {
        // NOTE: following code is heavily based on super's internals !
        synchronized(this) {
            // we're normally in the lock here (from #publish) 
            // thus we do not perform any more synchronization            
            Boolean rotatable = (Boolean) getField(rotatableField);
            try {
                setField(rotatableField, Boolean.FALSE);
                // thus current file name will be always {prefix}{suffix} :
                // due super's `prefix + (rotatable ? _date : "") + suffix`
                super.openWriter();
            }
            finally {
                setField(rotatableField, rotatable);
            }
        }
    }
    
    private boolean closing = false;
    
    @Override
    public void close() {
        closing = true;
        super.close(); // closeWriter()
        closing = false;
    }

    @Override
    protected void closeWriter() {
        String date = (String) getField(dateField);
        super.closeWriter(); // sets `date = null`
        boolean rotatable = isRotatable();
        if ( ! rotatable || closing ) return; // no rotation ...
        // the additional trick here is to rotate the closed file
        synchronized(this) {
            // we're normally in the lock here (from #publish) 
            // thus we do not perform any more synchronization
            File dir = new File( getDirectory() ).getAbsoluteFile();
            File log = new File(dir, getPrefix() + "" + getSuffix());
            if ( log.exists() ) {
                if ( date == null || date.isEmpty() ) {
                    final long lastMod = log.lastModified();
                    // we abuse Timestamp to get a date formatted !
                    // just like super does internally (just in case)
                    date = new java.sql.Timestamp(lastMod).toString().substring(0, 10);
                }
                final long todayMS = System.currentTimeMillis();
                String today = new java.sql.Timestamp(todayMS).toString().substring(0, 10);
                if ( date.equals(today) ) return; // no need to rotate just yet
                File toFile = new File(dir, getPrefix() + date + getSuffix());
                if ( toFile.exists() ) {
                    try {
                        RandomAccessFile file = new RandomAccessFile(toFile, "rw");
                        file.seek( file.length() );
                        FileChannel logChannel = new FileInputStream(log).getChannel();
                        logChannel.transferTo(0, logChannel.size(), file.getChannel());
                        file.close();
                        logChannel.close();
                        log.delete();   
                    }
                    catch (IOException e) {
                        throw new RuntimeException(e);
                    }
                }
                else {
                    log.renameTo(toFile);
                }
            }
        }
    }
    
    public String getDirectory() {
        return (String) getField(directoryField);
    }

    public void setDirectory(String directory) {
        setField(directoryField, directory);
    }
    
    public String getPrefix() {
        return (String) getField(prefixField);
    }

    public void setPrefix(String prefix) {
        setField(prefixField, prefix);
    }
    
    public String getSuffix() {
        return (String) getField(suffixField);
    }

    public void setSuffix(String suffix) {
        setField(suffixField, suffix);
    }
    
    public boolean isRotatable() {
        Boolean rotatable = (Boolean) getField(rotatableField);
        return Boolean.TRUE.equals(rotatable);
    }
    
    public void setRotatable(boolean rotate) {
        setField(rotatableField, rotate);
    }
    
    public Integer getBufferSize() {
        return (Integer) getField(bufferSizeField);
    }

    public void setBufferSize(Integer bufferSize) {
        setField(bufferSizeField, bufferSize);
    }
    
    private void setField(Field field, Object value) {
        try {
            field.set(this, value);
        }
        catch (IllegalAccessException e) {
            throw new RuntimeException(e);
        }
    }

    private Object getField(Field field) {
        try {
            return field.get(this);
        }
        catch (IllegalAccessException e) {
            throw new RuntimeException(e);
        }
    }
    
}
