require 'open-uri'
require 'fileutils'
include FileUtils


TOMCAT_CORE_PATH = File.expand_path('../../trinidad-libs/tomcat-core.jar', __FILE__)
TOMCAT_MAVEN_REPO = 'http://repo2.maven.org/maven2/org/apache/tomcat'

catalina = "#{TOMCAT_MAVEN_REPO}/catalina/%s/catalina-%s.jar"
coyote = "#{TOMCAT_MAVEN_REPO}/coyote/%s/coyote-%s.jar"
juli = "#{TOMCAT_MAVEN_REPO}/juli/%s/juli-%s.jar"
jsp_api = "#{TOMCAT_MAVEN_REPO}/jsp-api/%s/jsp-api-%s.jar"
servlet_api = "#{TOMCAT_MAVEN_REPO}/servlet-api/%s/servlet-api-%s.jar"
jasper = "#{TOMCAT_MAVEN_REPO}/jasper/%s/jasper-%s.jar"
jasper_el = "#{TOMCAT_MAVEN_REPO}/jasper-el/%s/jasper-el-%s.jar"
annotations_api = "#{TOMCAT_MAVEN_REPO}/annotations-api/%s/annotations-api-%s.jar"
el_api = "#{TOMCAT_MAVEN_REPO}/el-api/%s/el-api-%s.jar"

dependencies = [catalina, coyote, juli, jsp_api, servlet_api, jasper, jasper_el, annotations_api, el_api]

namespace :tomcat do
  desc "Updates Tomcat to a given version"
  task :update, :version do |task, args|
    tomcat_version = [args[:version]] * 2

    cd ENV['TMPDIR'] do
      # get Tomcat startup classes because they are not included in the 6.0.x branch
      %x{jar -xf #{TOMCAT_CORE_PATH} org/apache/catalina/startup}

      dependencies.each do |dependency|
        dependency_path = dependency % tomcat_version
        dependency_name = dependency_path.split('/').last

        # dowload dependencies
        puts "downloading #{dependency_path}"
        file = open(dependency_path)
        %x{jar -xf #{file.path}}
      end

      # build the jar again
      %x{jar -cvf #{TOMCAT_CORE_PATH} META-INF javax org}
    end
    puts "DONE - the Tomcat's version has been updated succesfully, please build Trinidad again."
  end
end
