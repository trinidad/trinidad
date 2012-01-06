# Trinidad

Trinidad allows you to run a rails or rackup applications within an embedded Apache Tomcat container.

* Mail list: http://groups.google.com/group/rails-trinidad
* Bug tracker: http://github.com/trinidad/trinidad/issues
* Irc channel on Freenode: #trinidad

## Installation

```
$ jruby -S gem install trinidad
```

## Quick Start

```
$ cd myapp
$ jruby -S trinidad
```

### Advanced Rackup setup

**Sinatra**

You can run your Sinatra application with Trinidad from the command line like this:

```
$ ruby app.rb -s Trinidad
```

Or tou can configure your application to always use it:

```ruby
require 'sinatra'
require 'trinidad'

configure do
  set :server, :trinidad
end
```

If you use Bundler, make sure you add Trinidad to your Gemfile:

```
gem 'trinidad'
```

**Rails**

If you already have Trinidad in your Gemfile you can start the server with the rails command:

```
$ rails s trinidad
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

Trinidad allows you to configure some parameters when the server is started from the command line, the following is a list of the currently supported options:

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
You can also specify a default web.xml to configure your web application. By default the server tries to load the file `config/web.xml` but you can modify this path by adding the option `default_web_xml` within your configuration file.

Other advanced options can be found on the wiki: http://wiki.github.com/trinidad/trinidad/advanced-configuration

### Yaml comfiguration

The server can also be configured from a yaml file. By default, if a file is not specified, the server tries to load the file `config/trinidad.yml`. Within this file you can add other options like jruby.min.runtimes(:jruby _ min _ runtimes) or jruby.max.runtimes(:jruby _ max _ runtimes).

```
$ jruby -S trinidad --config my_custom_configuration.yml
```

```yml
---
  port: 4000
  address: 0.0.0.0
```

### Ruby configuration

You can use pure ruby to configure Trinidad. Actually, the yaml configuration file is mapped directly into this configuration. It follows the same convention as the yaml configuration so the file `config/trinidad.rb` is loaded by default if if exists.

```ruby
Trinidad.configure do |config|
  config.port = 4000
  config.address = '0.0.0.0'
end
```

## Hot deployment

Although the early versions of Trinidad used an extension to let deploy applications monitorizing a file, since Trinidad 1.1.0 this feature is integrated into the core. When the file `tmp/restart.txt` is modified, the server reloads the application that the file belongs. This file can be modified with the option `monitor`.

## Virtual hosts

It's posible to configure Trinidad with multiple hosts and load the applications under them automatically. Take into account that each host must have its applications in a different directory.

```ruby
Trinidad.configure do |config|
  config.hosts = {
    # applications_path => host_name_list (the first one in the list is real host name, the other ones are aliases)
    'app_local' => ['localhost', '127.0.0.1'],
    'apps_lol'  => ['lolhost', 'lol'],
    'apps_foo'  => 'foo'
  }
end
```

If the applications are configured via the web_apps section, the host for each app can be added with the key `hosts` under each application. If several applications belong to the same host put them under the same directory and specify the name of the host for each one:

```ruby
Trinidad.configure do |config|
  config.web_apps = {
    :mock1 => {
      :web_app_dir => 'rails_apps/mock1',
      # host_name_list (the first one in the list is real host name, the other ones are aliases)
      :hosts       => ['rails.virtual.host', 'rails.host']
    },
    :mock2 => {
      :web_app_dir => 'rails_apps/mock2',
      :hosts       => 'rails.virtual.host'
    },
    :mock3 => {
      :web_app_dir => 'rack_apps/mock3',
      # host_name_list (the first one in the list is real host name, the other ones are aliases)
      :hosts       => ['rack.virtual.host', 'rack.host']
    }
  }
end
```

## Extensions

From the version 0.8.0 Trinidad allows to extend the server with more Tomcat features, here there is a list with the current available extensions:


* Database connection pooling: https://github.com/trinidad/trinidad_dbpool_extension
* Daemon based on Akuma (ala GF gem): http://github.com/trinidad/trinidad_daemon_extension
* Init services based on Apache Commons Daemon (supports Unix and Windows systems): http://github.com/trinidad/trinidad_init_services
* Sandbox, management console and REST api: http://github.com/trinidad/trinidad_sandbox_extension
* Logging, enhance the Trinidad's logging system: http://github.com/trinidad/trinidad_logging_extension
* Lifecycle, application and server lifecycle management: http://github.com/trinidad/trinidad_lifecycle_extension
* Scheduler, based on Quartz: http://github.com/trinidad/trinidad_scheduler_extension


You can find further information on how to write your own extension in the wiki: http://wiki.github.com/trinidad/trinidad/extensions

## Copyright

Copyright (c) 2011 David Calavera<calavera@apache.org>. See LICENSE for details.
