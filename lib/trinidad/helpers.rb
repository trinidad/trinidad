module Trinidad
  module Helpers

    # @private
    @@silence = nil
    # Should we be silent - no warnings will be printed.
    def self.silence?; @@silence; end
    # Silence ! (... or I kill you)
    def self.silence!; @@silence = true; end

    # Print a warning (using `Kernel.warn`).
    def self.warn(msg)
      super unless silence? # Kernel.warn
    end

    module_function

    # @private
    @@deprecated = {}

    # Print a deprecated message (once - no matter how many times it's called).
    def deprecated(msg, prefix = '[DEPRECATED] ')
      return nil if @@deprecated[msg]
      @@deprecated[msg] = true
      Helpers.warn "#{prefix}#{msg}" # Kernel.warn
    end
    # @private
    def deprecate(msg); deprecated(msg) end

    # Camelizes the passed (string) parameter.
    # @return a new string
    def camelize(string)
      string = string.to_s.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string.gsub!('/', '::')
      string
    end

    # a Hash like `symbolize` helper
    def symbolize(hash, deep = true)
      new_options = hash.class.new
      hash.each do |key, value|
        if deep && value.is_a?(Array) # YAML::Omap is an Array
          array = new_options[key.to_sym] = value.class.new
          value.each do |v|
            array << ( hash_like?(v) ? symbolize(v, deep)  : v )
          end
        elsif deep && hash_like?(value)
          new_options[key.to_sym] = symbolize(value, deep)
        else
          new_options[key.to_sym] = value
        end
      end
      new_options
    end

    # a Hash like `deep_merge` helper
    def merge(target, current, deep = true)
      return target unless current
      target_dup = target.dup
      current.keys.each do |key|
        target_dup[key] =
          if deep && hash_like?(target[key]) && hash_like?(current[key])
            merge(target[key], current[key], deep)
          else
            current[key]
          end
      end
      target_dup
    end

    def hash_like?(object)
      object.is_a?(Hash) || ( object.respond_to?(:keys) && object.respond_to?(:'[]') )
    end

  end
end