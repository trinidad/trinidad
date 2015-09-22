
load File.expand_path('../../trinidad-libs/tomcat-core.jar', File.dirname(__FILE__))
load File.expand_path('../../trinidad-libs/trinidad-rb.jar', File.dirname(__FILE__))

module Trinidad
  TRINIDAD_JARS_VERSION = '1.4.1j'
  TOMCAT_VERSION = '7.0.54' unless const_defined?(:TOMCAT_VERSION)

  ( Tomcat = Java::RbTrinidad::Jerry ).module_eval do
    include_package 'org.apache.catalina'
    include_package 'org.apache.catalina.startup'
    include_package 'org.apache.catalina.core'
    include_package 'org.apache.catalina.deploy'
    include_package 'org.apache.catalina.loader'

    include_package 'org.apache.naming.resources'
    include_package 'org.apache.tomcat'

    java_import 'org.apache.catalina.connector.Connector'
    java_import 'org.apache.catalina.util.ContextName'
  end
end
