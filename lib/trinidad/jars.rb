module Trinidad
  
  require "servlet-api-2.5-6.1.14"
  require "core-3.1.1"
  require "jsp-api-2.1"
  require "jsp-2.1"
  require 'tomcat-core'
  require 'jetty-util-6.1.14'
  
  require "jruby-rack-0.9.5-SNAPSHOT"
  
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
    include_package "org.jruby.rack"
    include_package "org.jruby.rack.rails"
  end
end