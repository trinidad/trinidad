# -*- encoding: utf-8 -*-
#$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name              = 'trinidad_jars'
  
  file = File.expand_path("../lib/trinidad/jars.rb", __FILE__)
  line = File.read(file)[/^\s*TRINIDAD_JARS_VERSION\s*=\s*.*/]
  s.version = line.match(/.*TRINIDAD_JARS_VERSION\s*=\s*['"](.*)['"]/)[1]
  
  s.summary     = "Jars packaged for Trinidad"
  s.description = "Bundled version of Tomcat and a slice of Java required by Trinidad."
  
  s.authors  = ["David Calavera"]
  s.email    = 'calavera@apache.org'
  s.homepage = 'http://github.com/trinidad/trinidad'
  
  s.require_paths = %w[lib]
  
  s.files = `git ls-files`.split("\n").sort.
    select { |file| file == 'trinidad_jars.gemspec' ||
                    file == 'lib/trinidad/jars.rb'  ||
                    file =~ /^trinidad-libs\// }
end