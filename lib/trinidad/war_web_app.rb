module Trinidad
  class WarWebApp < WebApp
    def context_path
      super.gsub(/\.war$/, '')
    end

    def work_dir
      File.join(web_app_dir.gsub(/\.war$/, ''), 'WEB-INF')
    end

    def monitor
      File.expand_path(web_app_dir)
    end

    def define_lifecycle
      Trinidad::Lifecycle::War.new(self)
    end
  end
end
