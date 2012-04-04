namespace :trinidad do
  
  def trinidad_version
    version("lib/trinidad/version.rb", 'VERSION')
  end

  def trinidad_gem_file
    "trinidad-#{trinidad_version}.gem"
  end

  desc "Build trinidad gem"
  task :build do
    build('trinidad.gemspec', trinidad_gem_file)
  end

  desc "Install trinidad gem"
  task :install => :build do
    sh "gem install pkg/#{trinidad_gem_file}"
  end
  
  desc "Release trinidad gem"
  task :release => :build do
    release('trinidad', trinidad_gem_file, trinidad_version)
  end
  
end