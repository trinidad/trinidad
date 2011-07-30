module Trinidad
  class JavaWebApp < WebApp
    def work_dir
      'WEB-INF'
    end

    def define_lifecycle
      Trinidad::Lifecycle::Java.new(self)
    end
  end
end
