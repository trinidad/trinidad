require 'open-uri'
require 'tmpdir'

namespace :tomcat do
  
  TOMCAT_CORE_JAR = File.expand_path('../../trinidad-libs/tomcat-core.jar', __FILE__)
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
  
  TARGET_DIR = File.expand_path('../../target', __FILE__)
  
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
    puts "`export trinidad_jars=true && bundle install` to use the local trinidad_jars gem with bundler"
  end

  task :compile do
    FileUtils.mkdir TARGET_DIR unless File.exists?(TARGET_DIR)
    sh 'javac -Xlint:deprecation -Xlint:unchecked -g -source 1.6 -target 1.6 ' + 
       "-classpath #{TOMCAT_CORE_JAR} -d #{TARGET_DIR} " + 
       Dir["src/java/**/*.java"].join(" ")
  end
  
  task :patch => :compile do
    Dir.chdir(TARGET_DIR) do
      entries = Dir.entries(TARGET_DIR) - [ '.', '..']
      puts "updating #{TOMCAT_CORE_JAR}"
      %x{jar -uvf #{TOMCAT_CORE_JAR} #{entries.join(' ')}}
    end
  end

  task :clean do
    rm_r TARGET_DIR if File.exist?(TARGET_DIR)
    rm TOMCAT_CORE_JAR if File.exist?(TOMCAT_CORE_JAR)
  end
  
end