require 'fakefs/safe'
module FakeApp
  def create_default_config_file
    @default ||= config_file 'config/trinidad.yml', <<-EOF
---
  port: 8080
EOF
  end

  def create_custom_config_file
    @custom ||= config_file 'config/tomcat.yml', <<-EOF
---
  environment: production
  ajp:
    port: 8099
    secure: true
EOF
  end

  def create_rails_web_xml
    @rails_web_xml ||= config_file 'config/web.xml', <<-EOF
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
    </listener>

</web-app>
EOF
  end

  def create_rackup_web_xml
    @rackup_web_xml ||= config_file 'config/web.xml', <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<web-app>
    <context-param>
      <param-name>jruby.min.runtimes</param-name>
      <param-value>1<param-value>
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
    @rackup ||= config_file File.join(path, 'config.ru'), <<-EOF
require 'rubygems'
require 'sinatra'

run App
EOF
  end

  private
  def config_file(path, content)
    File.open(path, 'w') {|io| io.write(content) }
  end
end
