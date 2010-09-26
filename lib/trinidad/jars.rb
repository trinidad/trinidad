TRINIDAD_LIBS = File.dirname(__FILE__) + "/../../trinidad-libs" unless defined?(TRINIDAD_LIBS)
$:.unshift(TRINIDAD_LIBS) unless 
  $:.include?(TRINIDAD_LIBS) || $:.include?(File.expand_path(TRINIDAD_LIBS))

module Trinidad
  require 'tomcat-core'
  TRINIDAD_JARS_VERSION = '0.3.2'
  TOMCAT_VERSION = '7.0.2' unless defined?(Trinidad::TOMCAT_VERSION)

  module Tomcat
    include_package 'org.apache.catalina'
    include_package 'org.apache.catalina.startup'
    include_package 'org.apache.catalina.core'
    include_package 'org.apache.catalina.deploy'
    include_package 'org.apache.catalina.loader'
 
    include_package 'org.apache.naming.resources'

    import 'org.apache.catalina.connector.Connector'
    import 'sun.security.tools.KeyTool'
  end

  module Rack
    include_package 'org.jruby.rack'
    include_package 'org.jruby.rack.rails'
  end
end
