# Trinidad

Trinidad allows you to run Rails or Rack applications within an embedded 
Apache Tomcat container.

* Mailing List: http://groups.google.com/group/rails-trinidad
* Bug Tracker: http://github.com/trinidad/trinidad/issues
* IRC Channel (on FreeNode): #trinidad

## Installation

```
$ jruby -S gem install trinidad
```

## Quick Start

```
$ cd myapp
$ jruby -S trinidad
```

### Setup

If you use Bundler, you might want to add Trinidad to your *Gemfile*:

```
gem 'trinidad', :require => nil
```

**Rails**

If you have Trinidad in your Gemfile you can start it with `rails server`:

```
$ rails s trinidad
```

or simply, if you prefer not to use the Rack handler, use:

```
$ trinidad
```

**Sinatra**

```
$ ruby app.rb -s Trinidad
```

or configure your application to always use Trinidad:

```ruby
require 'sinatra'
require 'trinidad'

configure do
  set :server, :trinidad
end
```

**Rackup**

You can pass the server name as an option to `rackup`:

```
$ rackup -s trinidad
```

Or you can set Trinidad by default in your `config.ru` file:

```
#\ -s trinidad
```

## Configuration

Trinidad allows you to configure parameters from the command line, the following 
is a list of the currently supported options (try `trinidad -h`):

```
  * -p, --port PORT               =>  port to bind to.
  * -e, --env ENVIRONMENT         =>  rails environment.
  * -c, --context CONTEXT         =>  application context path.
  * --lib, --jars LIBS_DIR        =>  directory containing jars.
  * --classes CLASSES_DIR         =>  directory containing classes.
  * -r, --rackup [RACKUP_FILE]    =>  run a provided rackup file instead of a rails application, by default it's config.ru.
  * --public PUBLIC_DIR           =>  specify the public directory for your application, by default it's 'public'.
  * -t, --threadsafe              =>  shortcut to work in threadsafe mode. Setting jruby_min_runtimes and jruby_max_runtimes to 1 in the configuration file the server behaves as the same way.
  * -l, --load EXTENSION_NAMES    =>  load extensions to use their command line options.
  * --address HOST                =>  set the server host.
  * -g, --log LEVEL               =>  set the log level, default INFO.
  * --apps APPS_BASE_DIRECTORY    =>  set the applications base directory.
```

You can also specify a default *web.xml* to configure your web application. 
By default the server tries to load the file *config/web.xml* but you can change
the path by adding the option `default_web_xml` within your configuration file.

### YAML Configuration

The server can also be configured from a .yml file. By default, if a file is 
not specified, the server tries to load *config/trinidad.yml*.
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
might be used to setup Trinidad. It follows the same convention as the yaml 
configuration - the file `config/trinidad.rb` is loaded by default if exists.

```ruby
Trinidad.configure do |config|
  config.port = 4242
  config.address = '0.0.0.0'
end
```

## Hot Deployment

Although the early versions of Trinidad used an extension to reload applications 
monitorizing a file, since Trinidad **1.1.0** this feature is baked in. 
When the file *tmp/restart.txt* is modified, the server reloads the application 
the file belongs. The monitored file can be customized with the `monitor` option.

## Virtual Hosts

It's possible to use Trinidad with multiple hosts and load the applications under 
them automatically. Please remember that each host must have its applications in 
a different directory.

```ruby
Trinidad.configure do |config|
  config.hosts = {
    # applications_path => host_name_list 
    # (first one is the real host name, the other ones are aliases)
    'app_local' => ['localhost', '127.0.0.1'],
    'apps_lol'  => ['lolhost', 'lol'],
    'apps_foo'  => 'foo'
  }
end
```

If applications are configured via the `web_apps` section, the host for each app
can be added with the `hosts` key under each application. 
If several applications belong to the same host put them under the same directory
and specify the name of the host for each one e.g. :

```ruby
Trinidad.configure do |config|
  config.web_apps = {
    :mock1 => {
      :web_app_dir => 'rails_apps/mock1',
      :hosts       => ['rails.virtual.host', 'rails.host']
    },
    :mock2 => {
      :web_app_dir => 'rails_apps/mock2',
      :hosts       => 'rails.virtual.host'
    },
    :mock3 => {
      :web_app_dir => 'rack_apps/mock3',
      :hosts       => ['rack.virtual.host', 'rack.host']
    }
  }
end
```

## Extensions

Trinidad allows to extend itself with more (not just Tomcat) features, 
here is a list of the available extensions that are "officially supported":

* Database Connection Pooling: http://github.com/trinidad/trinidad_dbpool_extension
* Daemonize Trinidad, based on Akuma: http://github.com/trinidad/trinidad_daemon_extension
* Init Services (for Unix and Windows), based on Commons Daemon: http://github.com/trinidad/trinidad_init_services
* Logging, enhance Trinidad's logging system: http://github.com/trinidad/trinidad_logging_extension
* Application and Server Lifecycle Management: http://github.com/trinidad/trinidad_lifecycle_extension
* Trinidad's Management Console and REST API: http://github.com/trinidad/trinidad_sandbox_extension
* Scheduler, based on Quartz: http://github.com/trinidad/trinidad_scheduler_extension
* Valves - components inserted into the request pipeline (e.g. Access Log): http://github.com/trinidad/trinidad_valve_extension

You can find further information on how to write extensions in the wiki: 
http://wiki.github.com/trinidad/trinidad/extensions

## Copyright

Copyright (c) 2011-2012 David Calavera. See LICENSE for details.
