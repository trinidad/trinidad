## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'trinidad'
  s.version           = '0.9.7'
  s.date              = '2010-09-26'
  s.rubyforge_project = 'trinidad'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Simple library to run rails applications into an embedded Tomcat"
  s.description = "Trinidad allows you to run a rails or rackup applications within an embedded Apache Tomcat container"

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["David Calavera"]
  s.email    = 'calavera@apache.org'
  s.homepage = 'http://github.com/calavera/trinidad'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## If your gem includes any executables, list them here.
  s.executables = ["trinidad"]
  s.default_executable = 'trinidad'

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.rdoc LICENSE]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  s.add_dependency('trinidad_jars', ">= 0.3.0")
  s.add_dependency('jruby-rack', ">= 1.0.2")

  ## List your development dependencies here. Development dependencies are
  ## those that are only needed during development
  s.add_development_dependency('rspec')
  s.add_development_dependency('mocha')
  s.add_development_dependency('fakefs')

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
bin/trinidad
lib/trinidad.rb
History.txt
LICENSE
README.rdoc
lib/trinidad/command_line_parser.rb
lib/trinidad/core_ext.rb
lib/trinidad/extensions.rb
lib/trinidad/rackup_web_app.rb
lib/trinidad/rails_web_app.rb
lib/trinidad/server.rb
lib/trinidad/web_app.rb
lib/trinidad/web_app_lifecycle_listener.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  ## s.test_files = s.files.select { |path| path =~ %r{^spec/trinidad/.*_spec\.rb} }
end
