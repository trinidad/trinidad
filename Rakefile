require 'rubygems'
require 'rake'
require 'date'

def date
  Date.today.to_s
end

def replace_header(head, header_name, method_name = header_name)
  head.sub!(/(\.#{header_name}\s*= ').*'/) { "#{$1}#{send(method_name)}'"}
end

def version(file, constant)
 line = File.read(file)[/^\s*#{constant}\s*=\s*.*/]
 line.match(/.*#{constant}\s*=\s*['"](.*)['"]/)[1]
end

def build(gemspec_file, gem_file)
  sh "mkdir -p pkg"
  sh "gem build #{gemspec_file}"
  sh "mv #{gem_file} pkg"
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
  :release => 'Release all Trinidad gems'
}.each do |t, d|
  desc d
  task t => ["trinidad_jars:#{t}", "trinidad:#{t}"]
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['--color', "--format documentation"]
end

task :default => :spec
