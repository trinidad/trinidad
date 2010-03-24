module Trinidad
  class FooOptionsAddon

    def configure(*args)
      o = *args
      opts_parser = o[0]
      default_options = o[1]
      opts_parser.on('--foo', '--foo') do
        default_options[:foo] = :bar
      end
    end

  end

  class FooServerAddon
    def configure(*args)
    end
  end

  class FooWebAppAddon
    def configure(*args)
    end
  end
end
