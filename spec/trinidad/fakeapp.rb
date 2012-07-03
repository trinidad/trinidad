require 'fakefs/safe'
module FakeApp
  def create_default_config_file
    @default ||= create_config_file 'config/trinidad.yml', <<-EOF
---
  port: 8080
EOF
  end

  def create_custom_config_file
    @custom ||= create_config_file 'config/tomcat.yml', <<-EOF
---
  environment: production
  ajp:
    port: 8099
    secure: true
EOF
  end

  def create_erb_config_file
    @default ||= create_config_file 'config/trinidad.yml', <<-EOF
---
  port: <%= 4100 + 4200 %>
EOF
  end

  def create_rails_web_xml
    @rails_web_xml ||= create_config_file 'config/web.xml', <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://java.sun.com/xml/ns/j2ee"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://java.sun.com/xml/ns/j2ee http://java.sun.com/xml/ns/j2ee/web-app_2_4.xsd"
    version="2.4">

    <display-name>Trinidad Rails Test</display-name>
    <description>Trinidad Rails Test</description>

    <servlet>
        <servlet-name>RackServlet</servlet-name>
        <servlet-class>org.jruby.rack.RackServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>RackServlet</servlet-name>
        <url-pattern>/*</url-pattern>
    </servlet-mapping>

    <listener>
      <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>
    </listener>

</web-app>
EOF
  end

  def create_rackup_web_xml
    @rackup_web_xml ||= create_config_file 'config/web.xml', <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app>
    <context-param>
      <param-name>jruby.min.runtimes</param-name>
      <param-value>1</param-value>
    </context-param>

    <context-param>
      <param-name>jruby.max.runtimes</param-name>
      <param-value>1</param-value>
    </context-param>

    <servlet>
        <servlet-name>RackServlet</servlet-name>
        <servlet-class>org.jruby.rack.RackServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>RackServlet</servlet-name>
        <url-pattern>/*</url-pattern>
    </servlet-mapping>

    <listener>
      <listener-class>org.jruby.rack.RackServletContextListener</listener-class>
    </listener>

</web-app>
EOF
  end

  def create_rackup_file(path = 'config')
    @rackup ||= create_config_file File.join(path, 'config.ru'), <<-EOF
require 'rubygems'
require 'sinatra'

run App
EOF
  end

  def create_rails_web_xml_with_rack_servlet_commented_out
    create_config_file 'config/web.xml', <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app>
    <!--
    <servlet>
        <servlet-name>RackServlet</servlet-name>
        <servlet-class>org.jruby.rack.RackServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>RackServlet</servlet-name>
        <url-pattern>/*</url-pattern>
    </servlet-mapping>
    -->

    <listener>
      <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>
    </listener>

</web-app>
EOF
  end

  def create_rackup_web_xml_with_jruby_runtime_parameters_commented_out
    create_config_file 'config/web.xml', <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app>
    <!--
    <context-param>
      <param-name>jruby.min.runtimes</param-name>
      <param-value>1</param-value>
    </context-param>-->
    <!--
    <context-param>
      <param-name>jruby.max.runtimes</param-name>
      <param-value>1</param-value>
    </context-param>
    -->

    <servlet>
        <servlet-name>RackServlet</servlet-name>
        <servlet-class>org.jruby.rack.RackServlet</servlet-class>
    </servlet>
    <servlet-mapping>
        <servlet-name>RackServlet</servlet-name>
        <url-pattern>/*</url-pattern>
    </servlet-mapping>

    <listener>
      <listener-class>org.jruby.rack.RackServletContextListener</listener-class>
    </listener>

</web-app>
EOF
  end

  def create_rails_web_xml_formatted_incorrectly
    create_config_file 'config/web.xml', <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app>
    <servlet>
        <servlet-name>RackServlet</servlet-name>
        <servlet-class>org.jruby.rack.RackServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>RackServlet</servlet-name>
        <url-pattern>/*</url-pattern>
    </servlet-mapping>

    <listener>
      <listener-class>org.jruby.rack.rails.RailsServletContextListener</listener-class>
    <listener> <!-- MISSING CLOSING TAG -->

</web-app>
EOF
  end

  def create_rails_environment(env = 'environment.rb')
    create_config_file "config/#{env}", <<-EOF
    config.threadsafe!
EOF
  end

  def create_rails_environment_non_threadsafe(env = 'environment.rb')
    create_config_file "config/#{env}", <<-EOF
    # config.threadsafe!
EOF
  end

  protected
  def create_config_file(path, content)
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless File.exist?(dir)
    File.open(path, 'w') {|io| io.write(content) }
  end
  
end
