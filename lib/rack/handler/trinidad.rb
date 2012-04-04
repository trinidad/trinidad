# NOTE: require 'rack/handler/trinidad' might get invoked 2 ways :
# 1. Rack::Handler.try_require('rack/handler', 'trinidad') during rackup
#    in this case trinidad.rb might not yet been loaded
# 2. a user require (after trinidad.rb booted) - need to load rack first
require 'trinidad'
require 'rack/handler'
require 'rack/handler/servlet'

module Rack
  module Handler
    class Trinidad < Rack::Handler::Servlet
      def self.run(app, options={})
        opts = parse_options(options)

        servlet = create_servlet(app)
        opts[:servlet] = {:instance => servlet, :name => 'RackServlet'}

        ::Trinidad::CommandLineParser.load(opts)
        server = ::Trinidad::Server.new
        yield server if block_given?
        server.start
      end

      def self.valid_options
        {
          "Host=HOST"       => "Hostname to listen on (default: localhost)",
          "Port=PORT"       => "Port to listen on (default: 8080)",
          "Threads=MIN:MAX" => "min:max threads to use (default 1:1, threadsafe)",
        }
      end

      def self.parse_options(options = {})
        # some libs use :Port, :port and :Host, :host, unify this
        opts = {}
        options.each {|k, v| opts[k.to_s.downcase.to_sym] = v}

        # this is rack's configuration file but also the trinidad's configuration.
        # Removing it we allow to load trinidad's default configuration.
        opts.delete(:config)

        threads = (opts[:threads] || '1:1').split(':')
        opts[:port] ||= 3000
        opts[:address] ||= opts[:host] || 'localhost'
        # NOTE: this is currently not supported by embedded Dispatcher and has no effect :
        opts[:jruby_min_runtimes], opts[:jruby_max_runtimes] = threads[0].to_i, threads[1].to_i
        opts
      end

      def self.create_servlet(app)
        context = org.jruby.rack.embed.Context.new('Trinidad')
        dispatcher = org.jruby.rack.embed.Dispatcher.new(context, self.new(app))
        org.jruby.rack.embed.Servlet.new(dispatcher, context)
      end
    end

    register :trinidad, Trinidad
  end
end
