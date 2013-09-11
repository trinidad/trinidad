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

group :integration do
  gem "rails", "~> 3.2.13"
  gem "jruby-openssl" if JRUBY_VERSION < '1.7.0'
  # eval(File.read("spec/integration/rails32/Gemfile"), binding)
end
