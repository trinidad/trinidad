module Trinidad
  class WarWebApp < WebApp
    def context_path
      super.gsub(/\.war$/, '')
    end

    def work_dir
      web_app_dir.gsub(/\.war$/, '')
    end
  end
end
