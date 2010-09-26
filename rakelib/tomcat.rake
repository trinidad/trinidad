require 'open-uri'
require 'fileutils'
include FileUtils


TOMCAT_CORE_PATH = File.expand_path('../../trinidad-libs/tomcat-core.jar', __FILE__)
TOMCAT_MAVEN_REPO = 'http://repo2.maven.org/maven2/org/apache/tomcat'

catalina = "#{TOMCAT_MAVEN_REPO}/tomcat-catalina/%s/tomcat-catalina-%s.jar"
coyote = "#{TOMCAT_MAVEN_REPO}/tomcat-coyote/%s/tomcat-coyote-%s.jar"
juli = "#{TOMCAT_MAVEN_REPO}/tomcat-juli/%s/tomcat-juli-%s.jar"
jsp_api = "#{TOMCAT_MAVEN_REPO}/tomcat-jsp-api/%s/tomcat-jsp-api-%s.jar"
servlet_api = "#{TOMCAT_MAVEN_REPO}/tomcat-servlet-api/%s/tomcat-servlet-api-%s.jar"
jasper = "#{TOMCAT_MAVEN_REPO}/tomcat-jasper/%s/tomcat-jasper-%s.jar"
jasper_el = "#{TOMCAT_MAVEN_REPO}/tomcat-jasper-el/%s/tomcat-jasper-el-%s.jar"
annotations_api = "#{TOMCAT_MAVEN_REPO}/tomcat-annotations-api/%s/tomcat-annotations-api-%s.jar"
el_api = "#{TOMCAT_MAVEN_REPO}/tomcat-el-api/%s/tomcat-el-api-%s.jar"
embed = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-core/%s/tomcat-embed-core-%s.jar"
embed_jasper = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-jasper/%s/tomcat-embed-jasper-%s.jar"
embed_logging = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-logging-log4j/%s/tomcat-embed-logging-log4j-%s.jar"
utils = "#{TOMCAT_MAVEN_REPO}/tomcat-util/%s/tomcat-util-%s.jar"

dependencies = [
  catalina, coyote, juli, jsp_api, servlet_api, 
  jasper, jasper_el, annotations_api, el_api,
  embed, embed_jasper, embed_logging, utils
]

namespace :tomcat do
  desc "Updates Tomcat to a given version"
  task :update, :version do |task, args|
    tomcat_version = [args[:version]] * 2

    cd ENV['TMPDIR'] do
      dependencies.each do |dependency|
        dependency_path = dependency % tomcat_version
        dependency_name = dependency_path.split('/').last

        # dowload dependencies
        puts "downloading #{dependency_path}"
        file = open(dependency_path)
        %x{jar -xf #{file.path}}
      end

      # build the jar again
      puts "building the tomcat's core jar"
      %x{jar -cvf #{TOMCAT_CORE_PATH} META-INF javax org}
    end

    puts "updating tomcat's version number"
    path = File.expand_path('../../lib/trinidad/jars.rb', __FILE__)
    file = File.read(path)
    file.gsub!(/TOMCAT_VERSION = '(.+)'/, "TOMCAT_VERSION = '#{tomcat_version.first}'")
    File.open(path, 'w') { |io| io.write(file) }

    puts "DONE - the Tomcat's version has been updated succesfully, please build Trinidad again."
  end
end
