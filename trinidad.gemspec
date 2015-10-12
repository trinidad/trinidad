# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name = 'trinidad'

  path = File.expand_path("lib/trinidad/version.rb", File.dirname(__FILE__))
  gem.version = File.read(path).match( /.*VERSION\s*=\s*['"](.*)['"]/m )[1]

  gem.summary = "Web server for Rails/Rack applications built upon JRuby::Rack and Apache Tomcat"
  gem.description = "Trinidad allows you to run Rails or Rack applications within " <<
    "an embedded Apache Tomcat container. Serves your requests with the elegance of a cat !"

  gem.authors  = ['David Calavera']
  gem.email    = 'calavera@apache.org'
  gem.homepage = 'https://github.com/trinidad/trinidad'
  gem.licenses = ['MIT', 'Apache-2.0']

  gem.require_paths = %w[lib]
  gem.executables = ["trinidad"]
  gem.default_executable = 'trinidad'

  gem.rdoc_options = ["--charset=UTF-8"]
  gem.extra_rdoc_files = %w[README.md LICENSE]

  gem.add_dependency('trinidad_jars', '>= 1.5', '< 1.7')
  gem.add_dependency('jruby-rack', '~> 1.1.14') # '< 1.3'

  gem.add_development_dependency('rspec', '~> 2.14.1')

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