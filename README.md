# Trinidad

Trinidad allows you to run Rails and/or Rack applications within an embedded
Tomcat container. Apache Tomcat (formerly also Jakarta Tomcat) is an open source
web server and Servlet container with a long history that dates back to the
previous millenia.

Trinidad's goals with bringing Tomcat into JRuby land are mostly the following :

- **flexibility** especially in terms of configuration it allows you to tune
  (almost) everything from a simple *trinidad.yml* (or .rb) configuration file
- **portability** there's no vendor lock-in as we use `JRuby::Rack`, thus even
  if you do some Java integration or use it's Rack Servlet extensions you're
  still able to migrate to a standalone Tomcat or any other Servlet container
- easy Java integration (just in-case you need it, it's there)
- **extensions** such as connection pooling (sharing pools between deployed
  Rails apps) and (threaded) worker adapters for `Resque` and `Delayed::Job`

## Installation

[![gem version](https://badge.fury.io/rb/trinidad.png)](http://rubygems.org/gems/trinidad)
[![dependency status](https://gemnasium.com/trinidad/trinidad.png)][1]

```
$ jruby -S gem install trinidad
```

**NOTE:** consider testing out Trinidad **1.5.0.B1** `gem install trinidad --pre`

Trinidad requires (and supports) JRuby 1.6.8 or later (latest 1.7.x recommended).

## Quick Start

```
$ cd a-rails-app
$ jruby -S trinidad
```

## Setup

If you use Bundler, you might want to add Trinidad to your *Gemfile* :

```
gem 'trinidad', :require => nil
```

However this is not absolutely necessary, you might simply `gem install trinidad`
and than run `trinidad` - keep in mind a server is not an application dependency.

### Rails

Trinidad supports the same Rails version as the JRuby-Rack it founds (or is
specified/locked in your *Gemfile*), which is **2.3**, **3.x** as well as
**4.0** for JRuby-Rack 1.1.x (and the coming 1.2). Merb is not supported.

```
$ trinidad
```

or if you prefer to use the Rack handler (e.g. for development) use :

```
$ rails s trinidad
```

Please note all configuration options will work using the Rack handler mode, you
should usually only use it for development/tests and run `trinidad` on production.

### Sinatra

```
$ ruby app.rb -s Trinidad
```

or configure your application to always use Trinidad :

```ruby
require 'sinatra'
require 'trinidad'

configure do
  set :server, :trinidad
end
```

### Rackup

Trinidad auto-detects a plain-old Rack application (if there's a *config.ru*) :

```
$ trinidad
```

You can as well pass the server name to `rackup` to start the Rack handler :

```
$ rackup -s trinidad
```

Or you can set Trinidad as the default server in your *config.ru* file :

```
#\ -s trinidad
```

Trinidad solves the Rack "chicken-egg" problem when booting from a *rackup* file
the same way as JRuby-Rack (since it boots all applications), that is :
- if a Bundler *Gemfile* is detected, it first does a *bundle/setup* to load rack
- otherwise the rack (gem) version might be specified using a magic comment in
  *config.ru* as `# rack.version: ~>1.4.0` (or the latest installed gem is used)

**NOTE:** We do recommend to use the plain `trinidad` mode for running apps
(in production), since it supports runtime pooling while the "rackup" mode does
not, it also provides you with better Java integration possibilities.

Also note that Trinidad does not mimic JRuby-Rack's (1.1.x) backwards compatible
behavior of starting a pool for Rails but booting a thread-safe runtime for
plain Rack applications by default. Currently, runtime pooling is the default
with Trinidad and stays the same no matter the type of the application.
We expect this default to (most likely) change in a future version of Trinidad
as thread-safe gets more adopted by (stable) releases of Rails 4.0.

## Configuration

Trinidad allows you to configure parameters from the command line, the following
is a list of the currently supported options (try `trinidad -h`):

```
  * -d, --dir ROOT_DIR            =>  web application root directory
  * -e, --env ENVIRONMENT         =>  rack (rails) environment
  * --rackup [RACKUP_FILE]        =>  rackup configuration file
  * --public PUBLIC_DIR           =>  web application public root
  * -c, --context CONTEXT         =>  application context path
  * --monitor MONITOR_FILE        =>  monitor for application re-deploys
  * -t, --threadsafe              =>  force thread-safe mode (use single runtime)
  * --runtimes MIN:MAX            =>  use given number of min/max jruby runtimes
  * -f, --config [CONFIG_FILE]    =>  configuration file
  * --address ADDRESS             =>  host address
  * -p, --port PORT               =>  port to bind to
  * -s, --ssl [SSL_PORT]          =>  enable secure socket layout
  * -a, --ajp [AJP_PORT]          =>  enable the AJP web protocol
  * --java_lib LIB_DIR            =>  contains .jar files used by the app
  * --java_classes CLASSES_DIR    =>  contains java classes used by the app
  * -l, --load EXTENSION_NAMES    =>  load options for extensions
  * --apps_base APPS_BASE_DIR     =>  set applications base directory
  * -g, --log LEVEL               =>  set logging level
```

You can also specify a default *web.xml* to configure your web application.
By default the server tries to load the file *config/web.xml* but you can change
the path by adding the option `default_web_xml` within your configuration file.

### YAML Configuration

The server can be configured from a .yml file. By default, if a file is
not specified, the server tries to load **config/trinidad.yml**.
Within this file you can specify options available on the command line and tune
server settings or configure multiple applications to be hosted on the server.

Advanced configuration options are explained in the wiki:
http://wiki.github.com/trinidad/trinidad/advanced-configuration


```
$ jruby -S trinidad --config my_trinidad.yml
```

```yml
---
  port: 4242
  address: 0.0.0.0
```

### Ruby Configuration

As an alternative to the *config/trinidad.yml* file, a .rb configuration file
might be used to setup Trinidad. It follows the same convention as the YAML
configuration - the file **config/trinidad.rb** is loaded by default if exists.

```ruby
Trinidad.configure do |config|
  config.port = 4242
  config.address = '0.0.0.0'
  #config[:custom] = 'custom'
end
```

### Logging

As you might notice on your first `trinidad` the server uses standard output :

```
kares@theborg:~/workspace/trinidad/MegaUpload$ trinidad -p 8000 -e staging
Initializing ProtocolHandler ["http-bio-8000"]
Starting Servlet Engine: Apache Tomcat/7.0.28
Starting ProtocolHandler ["http-bio-8000"]
Context with name [/] has started rolling
Context with name [/] has completed rolling
```

It also prints warnings and error messages on error output, while application
specific log messages (e.g. logs from `Rails.logger`) always go into the expected
file location at *log/{environment}.log*.

Application logging performs daily file rolling out of the box and only prints
messages to the console while it runs in development mode, that means you won't
see any application specific output on the console say in production !

Please note that these logging details as well as the logging format will be
configurable with *trinidad.yml/.rb* within the next **1.4.x** release.

If you plan to use a slice of Java with your JRuby and require a logger, consider
using `ServletContext#log`. By default it is setup in a way that logging with
`ServletContext` ends up in the same location as the Rails log.
If this is not enough you can still configure a Java logging library e.g. SLF4J,
just make sure you tell Trinidad to use it as well, if needed, using the
**jruby.rack.logging** context parameter in *web.xml*.

### Context Configuration

For slightly advanced (and "dirty" XML :)) application configuration Trinidad
also supports the exact same *context.xml* format as Tomcat. Each web app is
represented as a context instance and might be configured as such. You do not
need to repeat configuring the same parameters you have already setup with the
Trinidad configuration. This is meant to be mostly for those familiar with
Tomcat internals.
Currently the application's *context.xml* is expected to be located on the
class-path under your *[classes]/META-INF* directory.

Context Doc: http://tomcat.apache.org/tomcat-7.0-doc/config/context.html

### Serving Assets

Trinidad uses Tomcat's built-in capabilities to server your public files.
We do recommend compiling assets up front and disabling the asset server (in
production) if you're using the asset pipeline in a Rails application.
If you do not put a web-server such as Apache in front of Trinidad you might
want to configure the resource caching (on by default for env != development)
for maximum performance e.g. by default it's configured as follows :

```yml
---
  public:
    root: public # same as the above "public: public" setting
    cached: true # enable (in-memory) asset caching on for env != 'development'
    cache_ttl: 5000 # cache TTL in millis (might want to increase this)
    cache_max_size: 10240 # the maximum cache size in kB
    cache_object_max_size: 512 # max size for a cached object (asset) in kB
    #aliases: # allows to "link" other directories into the public root e.g. :
      #/home: /var/local/www
```

Note that this configuration applies to (server-side) resource caching on top
of the "public" file-system. You do not need to worry about client side caching,
it is handled out of the box with *ETag* and *Last-Modified* headers being set.

You might also "mount" file-system directories as aliases to your resources
root to be served by your application (as if they were in the public folder).

**NOTE:** In development mode if you ever happen to `rake assets:precompile`
make sure to remove your *public/assets* directory later, otherwise requests
such as **/assets/application.js?body=1.0** might not hit the Rails runtime.

## Hot Deployment

Trinidad supports monitoring a file to reload applications, when the file
*tmp/restart.txt* is updated (e.g. `touch tmp/restart.txt` on Unix or
`type nul >>tmp\restart.txt & copy /b tmp\restart.txt +,,` on Windows),
the server reloads the application the monitor file belongs to.
This monitor file can be customized with the `monitor` configuration option.

Since version **1.4.0** Trinidad supports 2 reload strategies :

* **restart** (default) synchronous reloading. This strategy pauses incoming
  requests while it reloads the application and then serves them once ready
  (or timeouts if it takes too long). It is the default strategy since **1.4.0**
  due it's more predictable memory requirements.

* **rolling** a.k.a. "zero-downtime" (asynchronous) reloading strategy similar to
  Passenger's rolling reloads. This has been the default since **1.1.0** up till
  the **1.3.x** line. If you use this you should account that your JVM memory
  requirements might increase quite a lot (esp. if you reload under heavy loads)
  since requests are being served while there's another version of the
  application being loaded.

**NOTE:** due the way class-loaders where setup internally, Trinidad might have
failed releasing memory with reloads. This has been fixed in **1.5.0** please
consider updating, it is meant to be backwards compatible.

If you're on Java 6 you will likely need to tune your JAVA_OPTS / JRUBY_OPTS
for the JVM to do class unloading (consult the [wiki][6] for more information) :
```
JRUBY_OPTS="$JRUBY_OPTS -J-XX:+UseConcMarkSweepGC -J-XX:+CMSClassUnloadingEnabled"
```

Configure the reload strategy per web application or globally e.g. :

```yml
---
  port: 8080
  environment: production
  reload_strategy: rolling
```

## Virtual Hosts

It's possible to use Trinidad with multiple hosts and load the applications under
them automatically. A (virtual) host represents an association of a network name
(such as "www.example.com" with the particular server on which Tomcat is running.
Please remember that each host must have its applications in a different directory.
You can find out more at Tomcat's [documentation][4].

```ruby
Trinidad.configure do |config|
  config.hosts = {
    # applications path (host app base directory) => host names
    # (first one is the "main" host name, other ones are aliases)
    '/var/www/local/apps' => ['localhost', '127.0.0.1'],
    '/home/trinidad/apps' => 'appshost'
    # NOTE: by default a (default) 'localhost' host is setup
  }
end
```

Detailed host configuration is also possible using supported [host options][4] :

```yaml
---
  port: 8080
  hosts:
    localhost:
      app_base: /home/trinidad/apps
      auto_deploy: false
      unpackWARs: true
```

If applications are configured via the `web_apps` section, the host for each
application can be added with the `host` (or `hosts`) key, if a specified host
does not exists (e.g. not configured or not "localhost") it will be created.
If several applications belong to the same host, they are expected to reside
under the same parent directory e.g. :

```ruby
Trinidad.configure do |config|
  config.web_apps = {
    :mock1 => {
      :root_dir => 'rails_apps/mock1',
      :host     => ['rails.virtual.host', 'rails.host']
    },
    :mock2 => {
      :root_dir => 'rails_apps/mock2',
      :host     => 'rails.virtual.host'
    },
    :mock3 => {
      :root_dir => 'rack_apps/mock3',
      :host     => ['rack.virtual.host', 'rack.host']
    }
  }
end
```

## Extensions

Trinidad allows to extend itself with more (not just Tomcat) features using
extensions, they're essentially components hooked into Tomcat's life-cycle.
Here is a list of the available extensions that are "officially supported" :

* Database Connection Pooling :
  http://github.com/trinidad/trinidad_dbpool_extension
* Daemonize Trinidad, based on Akuma (Unix only) :
  http://github.com/trinidad/trinidad_daemon_extension
* Init Services (for Unix and Windows), based on Commons Daemon :
  http://github.com/trinidad/trinidad_init_services
* Scheduler, based on Quartz :
  http://github.com/trinidad/trinidad_scheduler_extension
* Worker, threaded workers (supports Resque, Delayed::Job) :
  http://github.com/trinidad/trinidad_worker_extension
* Logging, enhance Trinidad's logging system :
  http://github.com/trinidad/trinidad_logging_extension
* Application and Server Lifecycle Management :
  http://github.com/trinidad/trinidad_lifecycle_extension
* Valves - components inserted into the request pipeline (e.g. Access Log) :
  http://github.com/trinidad/trinidad_valve_extension
* Application/Deployment Monitoring based on PSI-Probe :
  http://github.com/trinidad/trinidad_probe_extension
* Enable remote JMX monitoring capabilities for Trinidad :
  http://github.com/trinidad/trinidad_jmx_remote_extension

You can find further information on how to write extensions in the [wiki][5].

## Support

* contact [kares][0] if your team needs JRuby or Trinidad help and support
* ask us for help on [gitter][2] or use [SO][3] ... we shall get notified
* we're also on the JRuby mailing List: http://wiki.jruby.org/MailingLists
* and the #jruby IRC [channel](http://webchat.freenode.net/?channels=jruby)
* please report issues at: https://github.com/trinidad/trinidad/issues

## Copyright

Copyright (c) 2016 [Team Trinidad](https://github.com/trinidad).
See LICENSE (http://en.wikipedia.org/wiki/MIT_License) for details.

[0]: http://kares.org
[1]: https://gemnasium.com/trinidad/trinidad
[2]: https://gitter.im/trinidad
[3]: http://stackoverflow.com/questions/tagged/jruby
[4]: http://tomcat.apache.org/tomcat-7.0-doc/config/host.html
[5]: https://github.com/trinidad/trinidad/wiki/extensions
[6]: https://github.com/trinidad/trinidad/wiki/JOPTS