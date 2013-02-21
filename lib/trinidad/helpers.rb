module Trinidad
  module Helpers

    @@silence = nil # :nodoc
    # Should we be silent - no warnings will be printed.
    def self.silence?; @@silence; end
    # Silence ! (... or I kill you)
    def self.silence!; @@silence = true; end

    # Print a warning (Kernel.warn).
    def self.warn(msg)
      super unless silence? # Kernel.warn
    end
    
    module_function

    @@deprecated = {} # :nodoc
    
    # Print a deprecated message (once - no matter how many times it's called).
    def deprecate(msg, prefix = '[DEPRECATED] ')
      return nil if @@deprecated[msg]
      @@deprecated[msg] = true
      Helpers.warn "#{prefix}#{msg}" # Kernel.warn
    end
    
    def camelize(string)
      string = string.to_s.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string.gsub!('/', '::')
      string
    end
    
  end
end