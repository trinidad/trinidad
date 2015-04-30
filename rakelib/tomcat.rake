require 'open-uri'
require 'tmpdir'

namespace :tomcat do
  include TrinidadRakeHelpers

  TOMCAT_MAVEN_REPO = 'http://repo2.maven.org/maven2/org/apache/tomcat'

  tomcat = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-core/%s/tomcat-embed-core-%s.jar"
  tomcat_jasper = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-jasper/%s/tomcat-embed-jasper-%s.jar"
  tomcat_logging = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-logging-log4j/%s/tomcat-embed-logging-log4j-%s.jar"

  dependencies = [ tomcat, tomcat_jasper, tomcat_logging ]

  task :fetch, :version do |_, args|
    tomcat_version = [args[:version]] * 2

    temp_dir = File.join(Dir.tmpdir, (Time.now.to_f * 1000).to_i.to_s)
    FileUtils.mkdir temp_dir
    Dir.chdir(temp_dir) do
      dependencies.each do |dependency|
        dependency_path = dependency % tomcat_version
        dependency_name = dependency_path.split('/').last

        # dowload dependencies
        puts "downloading #{dependency_path}"
        file = open(dependency_path)
        %x{jar -xf #{file.path}}
      end

      # build the jar again
      entries = Dir.entries(temp_dir) - [ '.', '..']
      puts "building #{TOMCAT_CORE_JAR}"
      %x{jar -cvf #{TOMCAT_CORE_JAR} #{entries.join(' ')}}
    end
    FileUtils.rm_r temp_dir
  end

  TOMCAT_CORE_TARGET_DIR = File.expand_path('../../target/tomcat-core', __FILE__)

  desc "Updates Tomcat to a given version e.g. `rake tomcat:update[7.0.30]`"
  task :update, :version do |_, args|
    Rake::Task['tomcat:fetch'].invoke(version = args[:version])
    Rake::Task['tomcat:patch'].invoke

    puts "updating tomcat's version number to '#{version}'"
    path = File.expand_path('../../lib/trinidad/jars.rb', __FILE__)
    file = File.read(path)
    file.gsub!(/TOMCAT_VERSION = '(.+)'/, "TOMCAT_VERSION = '#{version}'")
    File.open(path, 'w') { |io| io.write(file) }

    puts "DONE - Tomcat's version has been updated to #{version} succesfully !\n"
    puts "`export TRINIDAD_JARS_VERSION=local && bundle install` to make sure you use the local trinidad_jars gem with Bundler"
  end

  task :patch do
    Rake::Task['tomcat-core:jar'].invoke
  end

  task :clear do
    rm TOMCAT_CORE_JAR if File.exist?(TOMCAT_CORE_JAR)
  end
  task :clean => :clear

end

namespace :'tomcat-core' do

  task :compile do
    mkdir_p TOMCAT_CORE_TARGET_DIR unless File.exist?(TOMCAT_CORE_TARGET_DIR)
    javac "src/tomcat-core/java", TOMCAT_CORE_TARGET_DIR
  end

  task :jar => :compile do
    unless File.exist?(TOMCAT_CORE_JAR)
      fail "missing #{TOMCAT_CORE_JAR} run tomcat:update first"
    end
    jar TOMCAT_CORE_TARGET_DIR, TOMCAT_CORE_JAR
  end

  task :clear do
    rm_r TOMCAT_CORE_TARGET_DIR if File.exist?(TOMCAT_CORE_TARGET_DIR)
    rm TOMCAT_CORE_JAR if File.exist?(TOMCAT_CORE_JAR)
  end
  task :clean => :clear

end
