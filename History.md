## trinidad 1.5.0.B1 (2014-03-27)

* make sure the context.name does include the original name (after reload)
* set server's parent class-loader for Class.forName to work better from Tomcat
* add the jruby-rack.jar to web-app's loader instead of using the one loaded
* start defaulting to "sensible" thread-safe
  in development/test mode we shall start the same (thread-safe) way as in production
* set "reloader" (java) thread name for easier identification
* handle `address: *` since it broke on adding a JMX bean with * in it's name (which is not a valid one)
* allow to disable (inherited) web-app extension by specifying `name: false`
* remove some of the 'old' deprecated methods/configuration
* class-loader kung-fu to get thigns right towards leak free applications ...
* we're still binding by default to localhost/127.0.0.1 - change to '*' (#119)

## trinidad_jars 1.4.0 (2014-03-27)

* Tomcat 7.0.50 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html
* a "faster" (default) JarScanner for Rack/Rails applications
  based on TC's StandardJarScanner implementation
* an extended (default) web-app loader (to handle JRuby specific "leaks")
  as well as some MySQL and PostgreSQL JDBC driver specific cleanup

## trinidad 1.4.6 (2013-12-28)

* default :port for SSL is now (a more Ruby-sh) 3443
* better handling of port/address for connectors when only one configured
  e.g. in case users want https:// but not http://
* make sure we keep localhost for tomcat.server's address if not specified
* only generate 'dummy' SSL keystore if not done already (#117)
* getting more "strict" about jruby-rack and trinidad_jars gem versions
* use a custom context manager to have "truly" lazy (java) sessions (#123)
* improve thread-safe rails (4.0) auto-detection from environment files
* allow symlinks in assets FS e.g. public/assets might be linked (#120)
* do not default to 'localhost' (default host) but use :address as name (#119)

with (latest) JRuby-Rack 1.1.13 works on JRuby 1.6.x (even < 1.6.7) as well

## trinidad_jars 1.3.0 (2013-12-28)

* Tomcat 7.0.47 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html
* re-invent the MessageFormatter in Java
* introduce Jerry - Tomcat's little companion

## trinidad_jars 1.2.5 (2013-11-14)

* Tomcat 7.0.42 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad 1.4.5 (2013-06-14)

* server should set up AJP only (if HTTP not explicitly configured) (#113)
  make sure that address/port are being set on AJP as well
* make sure environment is converted to_s + check if specified in web.xml (#112)
* config[:host] might be a string (e.g. using rackup mode)

also see all changes in 1.4.5.B1 if upgrading from a previous stable

## trinidad_jars 1.2.4 (2013-06-12)

* Tomcat 7.0.41 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad_jars 1.2.3 (2013-04-26)

* Tomcat 7.0.39 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad 1.4.5.B1 (2013-03-08)

* Rails 4.0 threadsafe! detection
* only configure logging err handler if STDOUT/STDERR changed from JVM default
* correctly handle .war file + expanded .war dir (double) deploys
* better web app root resolution (relative to host's app base directory)
* (always) correctly categorize deployed apps into hosts
* support for more fine grained host configuration (including default host)
* (once again) working plain-old .war deployment support
* make sure context name (once set) is not changed and is kept esp. during
  rolling reloads even if (slightly) different from configured context_name
* fail-safe (zero-downtime) support for rolling reload
  when a new version of the app fails to boot the old one is kept
* depend on latest (>= 1.2.2) jars and jruby-rack >= 1.1.13
* review extensions resolution, ignore extension (warn) when it doesn't exist
* patch DirectJDKLog to disable log source thus we won't generate a dummy
  throwable just to obtain the caller stack trace (that ain't really used)
* handle immediate log level change with JUL's LogFactory
* avoid work_dir deletion on context destory (during rolling reloads)
* do not allow public.root ('/') to be used as FS root (#93)

## trinidad_jars 1.2.2 (2013-03-08)

* Tomcat 7.0.37 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad_jars 1.2.1 (2013-02-21)

* Tomcat 7.0.35 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad_jars 1.2.0 (2013-01-14)

* Tomcat 7.0.33 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html
* patched JULI's DirectJDKLog to not generate stack traces for every log
  by default (can be turned back using org.apache.juli.logging.logSource=true)
* native (Java) implementations for logging classes, to keep logging AFAP

## trinidad 1.4.4 (2012-10-19)

* make sure setting FileHandler's rotatable to false works (#82)
* first draft for web-app logging configuration to avoid use hacks e.g.
  for disabling rotation (this feature is not yet official and might change)
* fix new lines (ala default Rails.logger) in console output
* set correct (JRuby-Rack) layout for web apps and use app.root
  (besides rails.root)
* check whether (jruby.) params are specified in system properties (#92)
* fix JUL::ConsoleHandler - not setting up JRuby streams correctly (#88)

## trinidad_jars 1.1.1 (2012-10-17)

* Tomcat 7.0.32 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html
* avoid using the "global" (and redundant) TRINIDAD_LIBS constant
* load the .jar files instead of requiring them (no more $: polution)

## trinidad 1.4.3 (2012-09-20)

* allow to keep (and configure) the jsp servlet (support for serving .jsp pages)
* decreased jruby.runtime.acquire.timeout default from 10 to 5 seconds
* removed Threads=MIN:MAX option from Rack::Handler (makes no sense right now)
* trinidad (CLI) :
  - added --runtimes option to allow specifying pool size on command-line
  - deprecated libs_dir and classes_dir added java_lib and java_classes
  - deprecated --apps option and use the same name as in config --apps_base
  - now prints some more accurate defaults that are used
* leverage Tomcat's default servlet for serving static asset files :
  - use a customized default servlet to handle the public.root assets
  - support for providing aliases (to achieve desired backward compatibility)
  - support for allowing caching and tuning (asset) cache parameters
* allow absolute paths with :default_web_xml / :web_xml configuration option
* replace :libs_dir and :classes_dir with :java_lib and :java_classes options
  (backwards compatible) with sensible defaults *lib/java* and *lib/java/classes*
* make sure application :work_dir is actually being set on the context
  and change it by default to to [RAILS_ROOT]/tmp
* web application's :web_app_dir deprecated in favor of the :root_dir option
* make sure the rack servlet loads on startup by default
* allow init_params: to be configured with (rack/default) servlet options
* allow for default (servlet) overrides using default_servlet:
* better rack_servlet: configuration
  - accepts a servlet instance (and assumes it is configured)
  - 'rack' naming convention might be used to use custom servlet class
  - support for servlet :mapping and :load_on_startup options
* fix async_supported: option not propagating correctly into servlet
* support for loading META-INF/context.xml from the (classes) class-path

Requires JRuby-Rack >= 1.1.10 and thus includes the following features :

 - Rails 3.1+ `render stream: true` support with HTTP chunked encoding
 - initial compatibility with Rails master (getting torwards 4.0.0.beta)
 - all Rack applications now support pooling runtimes (not just Rails)
 - better and more predictable application pool initialization
 - support for fully leveraging the Servlet API for parameters/cookies
   this is useful for Java integration cases when a servlet/filter consumes
   the input stream before Rails (e.g. valves such as AccessLogValve).
   it is an experimental feature that might change in the future and
   currently requires setting 'jruby.rack.handler.env' param to 'servlet'

## trinidad_jars 1.1.0 (2012-09-20)

* include java code compiled into trinidad-rb.jar for Trinidad
* otherwise same as previous version (1.0.7) uses Tomcat 7.0.30

## trinidad 1.4.2 (2012-09-19) YANKED

## trinidad_jars 1.0.7 (2012-09-12)

* Tomcat 7.0.30 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad_jars 1.0.6 (2012-08-21)

* Tomcat 7.0.29 http://tomcat.apache.org/tomcat-7.0-doc/changelog.html

## trinidad 1.4.1 (2012-08-17)

* make sure file logging rotates correctly when file handler attempts rolling
  after midnight (#81)
* refined (backwards-compatible) extension API
  - options attr reader
  - override_tomcat? no longer needed simply return a tomcat duck
  - expose camelize + symbolize helpers
  - WebAppExtension should only get a single context argument on configure
* better rails (2.3/3.x) detection with environment.rb
* minor server updates
  - expose configured web_apps
  - add a trap? helper (for easier overrides)
  - introduce a stop! for stopping and destroying a the server

## trinidad 1.4.0 (2012-07-24)

* fix incorrect context-param parsing and only configure logging when
  deployment descriptor did not specified jruby.rack.logging param (#76)
* deep symbolize_options should account for arrays of hashes (#80)
* requires latest Tomcat 7.0.28 (jars 1.0.5) due context reloading fix
* requires latest jruby-rack 1.1.7 due delegating RackLogger to JUL
* Trinidad::WebApp API revisited some changes are non-backwards compatible !
* enable running multiple applications with different ruby versions (using the
  jruby_compat_version configuration option)
* allow arbitrary keys to be stored with Trinidad::Configuration
* changed Trinidad::Lifecycle::Base to be a (ruby-like) base lifecycle listener
  skeleton implementation, thus removed all web app specifics from the class
  (include Trinidad::Lifecycle::WebApp::Shared to gain the same functionality)
* removed unused Trinidad::Rack module and KeyTool from Trinidad::Tomcat
* reinvented server/application logging with Trinidad::Logging :
  - refactored Trinidad's global logging configuration with JUL
  - application logs into log/env.log by default with daily rolling
  - console logs are now less chatty and only print logs from applications
    running in development mode (configuration to come in a later release)
  - make sure Trinidad's custom log formatter prints thrown exceptions
  - use local timestamps with (file) log formatter by default
* Trinidad::Server#add_web_app for code re-use during rolling redeploys
* refactored application (monitor based `touch 'tmp/restart.txt'`) reloading
  - bring back synchronous context reloading and make it default
  - "zero downtime" async rolling reload is still supported and configurable via
    the reload_strategy: rolling configuration option
  - updated the context restart code - hot deploys should now work reliably (#75)
  - moved Trinidad::Lifecycle::Host under Trinidad::Lifecycle::WebApp::Host
  - Trinidad::Lifecycle::Host now accepts a server instance instead of a tomcat
  - introduced Trinidad::WebApp::Holder to be used instead of bare Hash
* add async_supported attribute for servlet (3.0) configuration

## trinidad_jars 1.0.5 (2012-07-03)

* Upgrade to Tomcat 7.0.28
* Patched org.apache.juli.FileHandler to allow daily rolling customization

## trinidad_jars 1.0.4 (2012-06-14)

* Upgrade to Tomcat 7.0.27

## trinidad_jars 1.0.3 (2012-04-04)

* Upgrade to Tomcat 7.0.26

## trinidad 1.3.5 (2012-04-04)

* Correctly detect :rackup from main config for web apps (#66)
* Rearrange trinidad.gemspec to be (always) usable with Bundler's :git paths.
* Use out/err streams from the Ruby runtime for logging instead of the default console log handler.
* Make sure tomcat exits on initialization failure.
* Yield from block passed to Trinidad's Rack::Handler

## trinidad 1.3.4 (2012-02-20)

* Do not explicitely load rack/handler/trinidad.rb, it solves load issues with trinidad_init_services.

## trinidad 1.3.3 (2012-02-16)

* Fix issues loading the default configuration file from the rack handler

## trinidad 1.3.2 (2012-01-13)

* Fix #29: Rack::Handler.register not found error

## trinidad 1.3.1 (2012-01-06)

* Fix Rack handler configuration issues

## trinidad_jars 1.0.2 (2011-12-31)

* Bump Tomcat's version to 7.0.23

## trinidad 1.3.0 (2011-12-30)

* Support for virtual hosts
* Ruby configuration DSL
* Rack handler

## trinidad 1.2.3 (2011-07-13)

* fix JRuby class loader generation with hot deploy

## trinidad 1.2.2 (2011-07-12)

* Better log formatter
* Allow to use an ERB template as configuration file
* Fix trinidad_init_services compatibility issues

## trinidad 1.2.1 (2011-06-15)

* Allow to specify the monitor file from the command line

## trinidad 1.2.0 (2011-05-24)

* Zero downtime hot deploy
* Autodetect framework and threadsafe environment
* Upgrade jruby-rack dependency to 1.0.9

## trinidad 1.1.1 (2011-03-27)

* Remove shared runtime initialization

## trinidad 1.1.0 (2011-03-18)

* Hot deployment integrated in the core gem
* Load config/trinidad.yml by default without the `-f` option if it exists
* Load config.ru for applications under the `apps_base` directory when the option is enabled
* Share the JRuby runtime with JRuby-Rack

## trinidad_jars 1.0.1 (2011-03-17)

* Upgrade to Tomcat 7.0.11

## trinidad_jars 1.0.0 (2011-01-18)

* Upgrade to Tomcat 7.0.6, first stable release of the Tomcat 7 branch.

## trinidad 1.0.5 (2011-01-13)

* Fix trailing spaces on arguments. Thank you Windows.

## trinidad 1.0.4 (2011-01-11)

* Add 'jruby.compat.version' parameter to let jruby-rack loads on 1.9 mode

## trinidad 1.0.3 (2010-12-08)

* fix TRINIDAD-31: fix bug causing trailing slashes errors loading assets

## trinidad 1.0.2 (2010-11-11)

* stop using application directory as work directory to prevent TRINIDAD-27 and other issues

## trinidad_jars 0.3.3 (2010-11-11)

* fix TRINIDAD-27: Tomcat 7.0.2 deletes working directory upon shutdown

## trinidad 1.0.1 (2010-11-04)

* fix problem loading lifecycle

## trinidad 1.0.0 (2010-11-04)

* Warbler support
* Add APR listener to run under native connectors
* fixes #24: setting address doesn't affect listening socket
* fix issues configuring the logger out of the lifecycle listener

## trinidad 0.9.12 (2010-10-21)

* fix problems loading tomcat classes from rack application
* fix xml parsing of web.xml. Thanks to Karol Bucek

## trinidad 0.9.11 (2010-10-20)

* configure applications base directory to run several applications into the same container

## trinidad 0.9.10 (2010-10-02)

* configure logging as expected by rails applications

## trinidad 0.9.9 (2010-09-29)

* set tomcat's server address properly

## trinidad 0.9.8 (2010-09-27)

* fix http connector protocol enabling nio

## trinidad 0.9.7 (2010-09-27)

* add option --adress to set the Trinidad's host

## trinidad_jars 0.3.2 (2010-09-26)

* fix TRINIDAD-21: trinidad_jars 0.3.1 breaks logging extension

## trinidad 0.9.6 (2010-09-12)

* add option to specify the application directory path from the command line

## trinidad_jars 0.3.1 (2010-09-12)

* update to Tomcat 7.0.2
* fix TRINIDAD-17: NPE when web app has a context path

## trinidad 0.9.5 (2010-08-08)

* fix TRINIDAD-15: trinidad defines String#camelize incompatibly with ActiveSupport: Argument is missing
* update JRuby-Rack dependency to avoid compatibility issues with rvm'

## trinidad 0.9.4 (2010-08-04)

* fix error configuring ssl

## trinidad 0.9.3 (2010-07-27)

* Tomcat updated to version 7.0.0
* fix TRINIDAD-9: Tomcat SSL configure options keystore and keystoreFile
* fix TRINIDAD-10: When a web.xml is provided the tomcat's context doesn't start properly

## trinidad 0.9.2 (2010-05-24)

* Autoload the rackup file when it's under the directory WEB-INF.
* Let jruby-rack reads the rackup file instead of passing its content as an init parameter.
* Allow to configure the rack servlet from the configuration options.
* Allow to use crt files to configure SSL

## trinidad 0.9.1 (2010-05-09)

* Move all configuration logic to a Lifecycle listener:
    - Keeps the initial configuration so the provided web xml files are no more needed.
    - Avoids workarounds in the hotdeploy extension.
* Disable more Tomcat's default behaviours. Process Tlds is also disabled.
* Allow to specify webapp extensions in the extensions root section.
* Allow to configure the Http connector.

## trinidad 0.9.0 (2010-04-28)

* Tomcat updated to version 6.0.26, added constant to get its version.
* Jars cleaned, 300kb less to load :)
* Default configuration file name moved from tomcat.yml to trinidad.yml
* Fixes bug merging configuration files
* Configuring application through web.xml to avoid weird lifecycle problems

## trinidad 0.8.3 (2010-04-17)

* Extensions improvements:
    - Enable command line extensions.
    - Allow to overload the server.

## trinidad 0.8.2 (2010-04-09)

* Fixes yaml parser error. Thank to @elskwid

## trinidad 0.8.1 (2010-04-06)

* Uses JRuby-Rack gem

## trinidad 0.8.0 (2010-04-04)

* Support for extensions (database connection pooling is the first one using it)
* Splitting the gem in two, the core gem and the jars gem

## trinidad 0.7.0 (2009-12-01)

* Support to run different applications within the same Tomcat container

## trinidad 0.6.0 (2009-11-02)

* Rackup compatibe frameworks support

## trinidad 0.5.0 (2009-10-27)

* JRuby-Rack updated to version 0.9.5
* Added Rack dependency to avoid using vendorized version

## trinidad 0.4.1 (2009-07-26)

* using jruby-rack development version to solve some bugs related with it.

## trinidad 0.4.0 (2009-07-16)

* support for ssl connections
* support for ajp connections

## trinidad 0.3.0 (2009-07-07)

* project renamed due to tomcat legal issues

## trinidad 0.2.0 (2009-06-23)

* custom configuration from a yaml file
* load options from a custom web.xml

## trinidad 0.1.2

* Autoload application custom jars and classes.
* Added some specs.
* Server refactor.

## trinidad 0.1

* Initial release.
* Running default rails applications.
