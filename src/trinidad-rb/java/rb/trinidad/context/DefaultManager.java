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

package rb.trinidad.context;

import org.apache.catalina.LifecycleException;
import org.apache.catalina.LifecycleState;
import org.apache.catalina.session.ManagerBase;
import org.apache.catalina.session.StandardManager;
import org.apache.catalina.util.SessionIdGenerator;
import org.apache.juli.logging.Log;
import org.apache.juli.logging.LogFactory;
import org.apache.tomcat.util.ExceptionUtils;

/**
 * Trinidad's default session manager implementation (for Rails/Rack web-apps).
 * It's been introduced to cut down startup cost while initializing the (Java)
 * session id generator which might take a second or few. Since most Rack/Rails
 * applications do not use the JavaSessionStore or access the Java session it
 * should be fine to only initialize on-demand.
 *
 * @see org.apache.catalina.session.ManagerBase
 * @see org.apache.catalina.session.StandardManager
 *
 * @author kares
 */
public class DefaultManager extends StandardManager {

    public DefaultManager() {
        super();
    }

    @Override
    public String getName() {
        return getClass().getSimpleName();
    }

    @Override
    public String getInfo() {
        return getName() + "/1.0";
    }

    @Override
    protected String generateSessionId() {
        if ( sessionIdGenerator == null ) { // we're lazy here
            synchronized(this) {
                if ( sessionIdGenerator == null ) {
                    initSessionIdGenerator();
                }
            }
        }
        return super.generateSessionId();
    }

    /**
     * Start this component and implement the requirements
     * of {@link org.apache.catalina.util.LifecycleBase#startInternal()}.
     *
     * @exception LifecycleException if this component detects a fatal error
     *  that prevents this component from being used
     */
    @Override
    protected synchronized void startInternal() throws LifecycleException {
        // super.startInternal() :

        // Load unloaded sessions, if any
        try {
            load();
        }
        catch (Throwable t) {
            ExceptionUtils.handleThrowable(t);
            final Log log = LogFactory.getLog(StandardManager.class);
            log.error(sm.getString("standardManager.managerLoad"), t);
        }

        setState(LifecycleState.STARTING);
    }

    @Override
    protected synchronized void stopInternal() throws LifecycleException {
        super.stopInternal(); // will set this.sessionIdGenerator = null;
    }

    private synchronized void initSessionIdGenerator() {
        // super.startInternal();
        // sets sessionIdGenerator = new SessionIdGenerator();

        // ManagerBase#startInternal :

        while (sessionCreationTiming.size() < TIMING_STATS_CACHE_SIZE) {
            sessionCreationTiming.add(null);
        }
        while (sessionExpirationTiming.size() < TIMING_STATS_CACHE_SIZE) {
            sessionExpirationTiming.add(null);
        }

        sessionIdGenerator = new SessionIdGenerator();
        sessionIdGenerator.setJvmRoute(getJvmRoute());
        sessionIdGenerator.setSecureRandomAlgorithm(getSecureRandomAlgorithm());
        sessionIdGenerator.setSecureRandomClass(getSecureRandomClass());
        sessionIdGenerator.setSecureRandomProvider(getSecureRandomProvider());
        sessionIdGenerator.setSessionIdLength(getSessionIdLength());

        // Force initialization of the random number generator
        //if (log.isDebugEnabled()) log.debug("Force random number initialization starting");
        sessionIdGenerator.generateSessionId();
        //if (log.isDebugEnabled()) log.debug("Force random number initialization completed");
    }

}