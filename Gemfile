source 'http://rubygems.org'

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

# for the integration tests :
group :test do
  gem "rails", "~> 3.2"
  gem "jruby-openssl"
end
