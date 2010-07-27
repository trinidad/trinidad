require 'rubygems'
require 'rake'

namespace :trinidad do
begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "trinidad"
    gem.summary = %Q{Simple library to run rails applications into an embedded Tomcat}
    gem.email = "calavera@apache.org"
    gem.homepage = "http://calavera.github.com/trinidad"
    gem.authors = ["David Calavera"]
    gem.rubyforge_project = 'trinidad'

    lib_files = Dir.glob('lib/trinidad/*').select {|d| !(d =~ /jars.rb$/)}

    gem.files = FileList['bin/*', 'lib/trinidad.rb', 'History.txt', 'LICENSE', 'README.rdoc', 'VERSION', *lib_files]

    gem.add_dependency 'rack', '>=1.0'
    gem.add_dependency 'jruby-rack', '>=1.0.1'
    gem.add_dependency 'trinidad_jars', '>=0.2.0'

    gem.add_development_dependency 'rspec'
    gem.add_development_dependency 'mocha'
    gem.add_development_dependency 'fakefs'
    gem.has_rdoc = false
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end
end

namespace :trinidad_jars do
begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "trinidad_jars"
    gem.summary = %Q{Common jars for Trinidad}
    gem.email = "calavera@apache.org"
    gem.homepage = "http://calavera.github.com/trinidad"
    gem.authors = ["David Calavera"]
    gem.rubyforge_project = 'trinidad_jars'

    gem.files = FileList['lib/trinidad/jars.rb', 'trinidad-libs/*.jar']
    gem.has_rdoc = false
    gem.version = '0.3.0'
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end
end

{
  :build => 'Build all Trinidad gems',
  :release => 'Release all Trinidad gems'
}.each do |t, d|
  desc d
  task t => ["trinidad_jars:#{t}", "trinidad:#{t}"]
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_opts = ['--options', "spec/spec.opts"]
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_opts = ['--options', "spec/spec.opts"]
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION.yml')
    config = YAML.load(File.read('VERSION.yml'))
    version = "#{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "trinidad #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rake/contrib/sshpublisher'
  namespace :rubyforge do

    desc "Release gem and RDoc documentation to RubyForge"
    task :release => ["rubyforge:release:gem"]

    namespace :release do
      desc "Publish RDoc to RubyForge."
      task :docs => [:rdoc] do
        config = YAML.load(
            File.read(File.expand_path('~/.rubyforge/user-config.yml'))
        )

        host = "#{config['username']}@rubyforge.org"
        remote_dir = "/var/www/gforge-projects/trinidad/"
        local_dir = 'rdoc'

        Rake::SshDirPublisher.new(host, remote_dir, local_dir).upload
      end
    end
  end
rescue LoadError
  puts "Rake SshDirPublisher is unavailable or your rubyforge environment is not configured."
end

