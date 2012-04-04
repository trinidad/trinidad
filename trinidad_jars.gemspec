# -*- encoding: utf-8 -*-
#$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'
  
  s.name              = 'trinidad_jars'
  s.rubyforge_project = 'trinidad_jars'
  
  file = File.expand_path("../lib/trinidad/jars.rb", __FILE__)
  line = File.read(file)[/^\s*TRINIDAD_JARS_VERSION\s*=\s*.*/]
  s.version = line.match(/.*TRINIDAD_JARS_VERSION\s*=\s*['"](.*)['"]/)[1]
  
  s.summary     = "Tomcat's jars packed for Trinidad"
  s.description = "Bundled version of Tomcat packed for Trinidad"
  
  s.authors  = ["David Calavera"]
  s.email    = 'calavera@apache.org'
  s.homepage = 'http://github.com/trinidad/trinidad'
  
  s.require_paths = %w[lib]
  
  s.files = `git ls-files`.split("\n").sort.
    select { |file| file == 'trinidad_jars.gemspec' || 
                    file == 'lib/trinidad/jars.rb'  || 
                    file =~ /^trinidad-libs\// }
  
end