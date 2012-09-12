TRINIDAD_LIBS = File.dirname(__FILE__) + "/../../trinidad-libs" unless defined?(TRINIDAD_LIBS)
$:.unshift(TRINIDAD_LIBS) unless 
  $:.include?(TRINIDAD_LIBS) || $:.include?(File.expand_path(TRINIDAD_LIBS))

module Trinidad
  require 'tomcat-core'
  TRINIDAD_JARS_VERSION = '1.0.7'
  TOMCAT_VERSION = '7.0.30' unless defined?(Trinidad::TOMCAT_VERSION)

  module Tomcat
    include_package 'org.apache.catalina'
    include_package 'org.apache.catalina.startup'
    include_package 'org.apache.catalina.core'
    include_package 'org.apache.catalina.deploy'
    include_package 'org.apache.catalina.loader'
 
    include_package 'org.apache.naming.resources'

    java_import 'org.apache.catalina.connector.Connector'
  end
end
