namespace :trinidad_jars do
  JARS_GEMSPEC = 'trinidad_jars.gemspec'

  def trinidad_jars_version
    version("lib/trinidad/jars.rb", 'TRINIDAD_JARS_VERSION')
  end

  def trinidad_jars_gem_file
    "trinidad_jars-#{trinidad_jars_version}.gem"
  end

  desc "Release trinidad_jars gem"
  task :release => :build do
    release('trinidad_jars', trinidad_jars_gem_file, trinidad_jars_version)
  end

  desc "Build trinidad_jars gem"
  task :build => :gemspec do
    build(JARS_GEMSPEC, trinidad_jars_gem_file)
  end

  desc "Update trinidad_jars gemspec"
  task :gemspec do
    # read spec file and split out manifest section
    spec = File.read(JARS_GEMSPEC)
    head, manifest, tail = spec.split("  # = MANIFEST =\n")

    replace_header(head, :version, :trinidad_jars_version)
    replace_header(head, :date)

    files = FileList['lib/trinidad/jars.rb', 'trinidad-libs/*.jar'].join("\n")

    # piece file back together and write
    manifest = "  s.files = %w[\n#{files}\n  ]\n"
    spec = [head, manifest, tail].join("  # = MANIFEST =\n")
    File.open(JARS_GEMSPEC, 'w') { |io| io.write(spec) }
    puts "Updated #{JARS_GEMSPEC}"
  end
end
