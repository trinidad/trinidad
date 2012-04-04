require 'rubygems'
require 'rake'

def version(file, constant)
 line = File.read(file)[/^\s*#{constant}\s*=\s*.*/]
 line.match(/.*#{constant}\s*=\s*['"](.*)['"]/)[1]
end

def build(gemspec_file, gem_file)
  mkdir_p 'pkg'
  sh "gem build #{gemspec_file}"
  mv gem_file, 'pkg'
end

def release(name, gem_file, version)
  unless `git branch` =~ /^\* master$/
    puts "You must be on the master branch to release!"
    exit!
  end
  sh "git commit --allow-empty -a -m 'Release #{name} #{version}'"
  sh "git tag v#{name}-#{version}"
  sh "git push origin master"
  sh "git push --tags"
  sh "gem push pkg/#{gem_file}"
end

{
  :build => 'Build all Trinidad gems',
  :install => 'Install all Trinidad gems',
  :release => 'Release all Trinidad gems'
}.each do |task, desc|
  desc desc
  task task => ["trinidad_jars:#{task}", "trinidad:#{task}"]
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['--color', "--format documentation"]
end

task :default => :spec
