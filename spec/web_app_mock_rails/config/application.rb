require File.expand_path('../boot', __FILE__)

module Rails
  def self.application
    return Object.new
  end
end