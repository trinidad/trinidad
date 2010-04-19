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

  private 
  def config_file(path, options)
    File.open(path, 'w') {|io| io.write(options) }
  end
end
