begin
  require 'bundler/gem_helper'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end

task :default => :spec

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['--color', "--format documentation"]
end

desc "Remove all build artifacts"
task :clear do
  sh "rm -rf pkg/"
end
task :clean => :clear

desc "Clear all jar artifacts"
task :clear_jars => [ 'tomcat:clear', 'tomcat-core:clear', 'trinidad-rb:clear' ] do
end
task :clean_jars => :clear_jars

['trinidad', 'trinidad_jars'].each do |name|
  gem_helper = Bundler::GemHelper.new(Dir.pwd, name)
  def gem_helper.version_tag
    "#{name}-#{version}" # override "v#{version}"
  end
  version = gem_helper.send(:version)
  version_tag = gem_helper.version_tag
  namespace name do
    desc "Build #{name}-#{version}.gem into the pkg directory"
    task('build') { gem_helper.build_gem }

    desc "Build and install #{name}-#{version}.gem into system gems"
    task('install') { gem_helper.install_gem }

    desc "Create tag #{version_tag} and build and push #{name}-#{version}.gem to Rubygems"
    task('release') { gem_helper.release_gem }
  end
end

TOMCAT_CORE_JAR = File.expand_path('../trinidad-libs/tomcat-core.jar', __FILE__)
TRINIDAD_RB_JAR = File.expand_path('../trinidad-libs/trinidad-rb.jar', __FILE__)

module TrinidadRakeHelpers
  
  def javac(source_dir, target_dir, class_path = TOMCAT_CORE_JAR)
    FileUtils.mkdir target_dir unless File.exist?(target_dir)
    sh 'javac -Xlint:deprecation -Xlint:unchecked -g -source 1.6 -target 1.6 ' + 
       "-classpath #{class_path} -d #{target_dir} " +
       Dir["#{source_dir}/**/*.java"].join(" ")
  end
  
  def jar(entries, jar_path)
    work_dir = Dir.pwd
    if entries.is_a?(String) && File.directory?(entries)
      work_dir = entries
      entries = Dir.entries(entries) - [ '.', '..' ]
    end
    Dir.chdir(work_dir) do
      update = File.exist?(jar_path)
      log "#{update ? 'updating' : 'creating'} #{jar_path}"
      options = update ? '-uvf' : '-cvf'
      %x{jar #{options} #{jar_path} #{entries.join(' ')}}
    end
  end
  
  def log(msg)
    puts msg
  end
  
end

namespace :'trinidad-rb' do
  include TrinidadRakeHelpers
  
  TRINIDAD_RB_TARGET_DIR = File.expand_path('../target/trinidad-rb', __FILE__)
  
  desc "Compile trinidad-rb java sources"
  task :compile do
    javac "src/trinidad-rb/java", TRINIDAD_RB_TARGET_DIR
  end
  
  desc "Package trinidad-rb.jar"
  task :jar => :compile do
    rm TRINIDAD_RB_JAR if File.exist?(TRINIDAD_RB_JAR)
    jar TRINIDAD_RB_TARGET_DIR, TRINIDAD_RB_JAR
  end
  
  desc "Remove trinidad-rb.jar"
  task :clear do
    rm_r TRINIDAD_RB_TARGET_DIR if File.exist?(TRINIDAD_RB_TARGET_DIR)
    rm TRINIDAD_RB_JAR if File.exist?(TRINIDAD_RB_JAR)
  end
  task :clean => :clear
  
end

task :build   => 'trinidad:build'
task :install => 'trinidad:install'
task :release => 'trinidad:release'
