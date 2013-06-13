# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'trinidad/version'

Gem::Specification.new do |gem|
  gem.name = 'trinidad'
  gem.version = Trinidad::VERSION

  gem.summary = "Web server for Rails/Rack applications built upon JRuby::Rack and Apache Tomcat"
  gem.description = "Trinidad allows you to run Rails or Rack applications within " <<
    "an embedded Apache Tomcat container. Serves your requests with the elegance of a cat !"

  gem.authors  = ["David Calavera"]
  gem.email    = 'calavera@apache.org'
  gem.homepage = 'http://github.com/trinidad/trinidad'

  gem.require_paths = %w[lib]
  gem.executables = ["trinidad"]
  gem.default_executable = 'trinidad'

  gem.rdoc_options = ["--charset=UTF-8"]
  gem.extra_rdoc_files = %w[README.md LICENSE]

  gem.add_dependency('trinidad_jars', ">= 1.2.2")
  gem.add_dependency('jruby-rack', ">= 1.1.13")

  gem.add_development_dependency('rake')
  gem.add_development_dependency('rspec', '~> 2.12.0')
  gem.add_development_dependency('mocha', '~> 0.12.1')
  gem.add_development_dependency('fakefs', '>= 0.4.0')

  gem.files = `git ls-files`.split("\n").sort.
    reject { |file| file =~ /^\./ }. # .gitignore, .travis.yml
    reject { |file| file =~ /^spec\// }. # spec/**/*.spec
    reject { |file| file =~ /^src\// }. # src/* compiled into the jars
    # reject trinidad_jars.gemspec files :
    reject { |file| file == 'trinidad_jars.gemspec' ||
                    file == 'lib/trinidad/jars.rb'  ||
                    file =~ /^trinidad-libs\// }

  gem.test_files = gem.files.select { |path| path =~ /^spec\/.*_spec\.rb/ }

end