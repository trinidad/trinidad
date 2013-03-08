
load File.expand_path('../../trinidad-libs/tomcat-core.jar', File.dirname(__FILE__))
load File.expand_path('../../trinidad-libs/trinidad-rb.jar', File.dirname(__FILE__))

module Trinidad
  TRINIDAD_JARS_VERSION = '1.2.2'
  TOMCAT_VERSION = '7.0.35' unless const_defined?(:TOMCAT_VERSION)

  module Tomcat
    include_package 'org.apache.catalina'
    include_package 'org.apache.catalina.startup'
    include_package 'org.apache.catalina.core'
    include_package 'org.apache.catalina.deploy'
    include_package 'org.apache.catalina.loader'
 
    include_package 'org.apache.naming.resources'

    java_import 'org.apache.catalina.connector.Connector'
    java_import 'org.apache.catalina.util.ContextName'
  end
end
