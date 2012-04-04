namespace :trinidad_jars do
  
  def trinidad_jars_version
    version("lib/trinidad/jars.rb", 'TRINIDAD_JARS_VERSION')
  end

  def trinidad_jars_gem_file
    "trinidad_jars-#{trinidad_jars_version}.gem"
  end

  desc "Build trinidad_jars gem"
  task :build do
    build('trinidad_jars.gemspec', trinidad_jars_gem_file)
  end

  desc "Install trinidad_jars gem"
  task :install => :build do
    sh "gem install pkg/#{trinidad_jars_gem_file}"
  end
  
  desc "Release trinidad_jars gem"
  task :release => :build do
    release('trinidad_jars', trinidad_jars_gem_file, trinidad_jars_version)
  end
  
end