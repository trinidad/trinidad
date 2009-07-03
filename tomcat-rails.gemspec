  # -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{tomcat-rails}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["David Calavera"]
  s.date = %q{2009-06-23}
  s.default_executable = %q{tomcat_rails}
  s.email = %q{david.calavera@gmail.com}
  s.executables = ["tomcat_rails"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "History.txt",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "TODO.txt",
     "VERSION",
     "bin/tomcat_rails",
     "lib/tomcat-rails.rb",
     "lib/tomcat-rails/command_line_parser.rb",
     "lib/tomcat-rails/jars.rb",
     "lib/tomcat-rails/server.rb",
     "lib/tomcat-rails/web_app.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb",
     "spec/tomcat-rails/command_line_parser_spec.rb",
     "spec/tomcat-rails/web_app_spec.rb",
     "spec/web_app_mock/classes/HelloTomcat.class",
     "spec/web_app_mock/config/web.xml",
     "spec/web_app_mock/lib/jyaml-1.3.jar",
     "spec/web_app_mock/tomcat.yml",
     "tomcat-libs/core-3.1.1.jar",
     "tomcat-libs/jasper-el.jar",
     "tomcat-libs/jasper-jdt.jar",
     "tomcat-libs/jasper.jar",
     "tomcat-libs/jetty-util-6.1.14.jar",
     "tomcat-libs/jruby-rack-0.9.4.jar",
     "tomcat-libs/jsp-2.1.jar",
     "tomcat-libs/jsp-api-2.1.jar",
     "tomcat-libs/servlet-api-2.5-6.1.14.jar",
     "tomcat-libs/tomcat-core.jar",
     "tomcat-libs/tomcat-dbcp.jar",
     "tomcat-libs/tomcat-jasper.jar",
     "tomcat-rails.gemspec"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://calavera.github.com/tomcat-rails}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.2}
  s.summary = %q{Simple library to run rails applications into an embedded Tomcat}
  s.test_files = [
    "spec/spec_helper.rb",
     "spec/tomcat-rails/command_line_parser_spec.rb",
     "spec/tomcat-rails/web_app_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
