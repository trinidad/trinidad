namespace :trinidad do
  GEMSPEC = 'trinidad.gemspec'

  def trinidad_version
    version("lib/trinidad.rb", 'VERSION')
  end

  def trinidad_gem_file
    "trinidad-#{trinidad_version}.gem"
  end

  desc "Release trinidad gem"
  task :release => :build do
    release('trinidad', trinidad_gem_file, trinidad_version)
  end

  desc "Build trinidad gem"
  task :build => :gemspec do
    build(GEMSPEC, trinidad_gem_file)
  end

  desc "Update trinidad gemspec"
  task :gemspec do
    # read spec file and split out manifest section
    spec = File.read(GEMSPEC)
    head, manifest, tail = spec.split("  # = MANIFEST =\n")

    replace_header(head, :version, :trinidad_version)
    replace_header(head, :date)

    lib_files = Dir.glob('lib/trinidad/*').select {|d| !(d =~ /jars.rb$/)}

    files = FileList['bin/*',
      'lib/trinidad.rb',
      'History.txt',
      'LICENSE',
      'README.rdoc',
      *lib_files].join("\n")

    # piece file back together and write
    manifest = "  s.files = %w[\n#{files}\n  ]\n"
    spec = [head, manifest, tail].join("  # = MANIFEST =\n")
    File.open(GEMSPEC, 'w') { |io| io.write(spec) }
    puts "Updated #{GEMSPEC}"
  end
end
