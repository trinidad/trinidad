source 'https://rubygems.org'

gemspec :name => "trinidad"

# NOTE: allows testing with various jar versions
if (jars = ENV['trinidad_jars']) && jars != 'false'
  if jars =~ /\d\.\d\.\d/
    # concrete version e.g. '1.0.8' or '>= 1.0.8'
    gem 'trinidad_jars', jars
  else
    # pre-release version e.g. `export trinidad_jars=true`
    gem 'trinidad_jars', :path => (jars == 'true' ? '.' : jars)
  end
end

gem 'sinatra', :require => nil, :group => :test

gem 'rake', :require => nil, :groups => [ :development, :test ]
group :development do
  jruby_version = ENV['JRUBY_VERSION']
  jruby_version = JRUBY_VERSION if jruby_version == 'current'
  jruby_version ||= '1.6.8' # by default compiling against JRuby 1.6.8
  gem 'jruby-jars', jruby_version, :require => nil # only for _javac_
end

group :integration do
  gem "rails", "~> 3.2.16"
  gem "jruby-openssl" if JRUBY_VERSION < '1.7.0'
  # eval(File.read("spec/integration/rails32/Gemfile"), binding)
end
