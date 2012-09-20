# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'trinidad/version'

Gem::Specification.new do |s|
  s.name = 'trinidad'
  s.version = Trinidad::VERSION
  
  s.summary = "Web server for Rails/Rack applications built upon JRuby::Rack and Apache Tomcat"
  s.description = "Trinidad allows you to run Rails or Rack applications within " + 
    "an embedded Apache Tomcat container. Serves your requests with the elegance of a cat !"
  
  s.authors  = ["David Calavera"]
  s.email    = 'calavera@apache.org'
  s.homepage = 'http://github.com/trinidad/trinidad'
  
  s.require_paths = %w[lib]
  s.executables = ["trinidad"]
  s.default_executable = 'trinidad'
  
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]
  
  s.add_dependency('trinidad_jars', ">= 1.1.0")
  s.add_dependency('jruby-rack', ">= 1.1.10")
  
  s.add_development_dependency('rack')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec', '~> 2.10')
  s.add_development_dependency('mocha')
  s.add_development_dependency('fakefs', '>= 0.4.0')
  s.add_development_dependency('sinatra')

  s.files = `git ls-files`.split("\n").sort.
    reject { |file| file =~ /^\./ }. # .gitignore, .travis.yml
    reject { |file| file =~ /^spec\// }. # spec/**/*.spec
    reject { |file| file =~ /^src\// }. # src/* compiled into the jars
    # reject trinidad_jars.gemspec files :
    reject { |file| file == 'trinidad_jars.gemspec' || 
                    file == 'lib/trinidad/jars.rb'  || 
                    file =~ /^trinidad-libs\// }
  
  s.test_files = s.files.select { |path| path =~ /^spec\/.*_spec\.rb/ }
  
end