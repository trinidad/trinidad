require 'trinidad'

require 'rack/handler'
require 'rack/handler/servlet'

module Rack
  module Handler
    class Trinidad < Rack::Handler::Servlet
      def self.run(app, options={})
        # some libs use :Port, :port and :Host, :host, unify this
        opts = {}
        options.each {|k, v| opts[k.to_s.downcase.to_sym] = v}

        threads = (opts[:threads] || '1:1').split(':')
        opts[:app] = app
        opts[:port] ||= 3000
        opts[:address] = opts[:host] || 'localhost'
        opts[:jruby_min_runtimes], opts[:jruby_max_runtimes] = threads[0].to_i, threads[1].to_i

        context = org.jruby.rack.embed.Context.new('Trinidad')
        dispatcher = org.jruby.rack.embed.Dispatcher.new(context, self.new(app))
        servlet = org.jruby.rack.embed.Servlet.new(dispatcher, context)

        opts[:servlet] = {:instance => servlet, :name => 'RackServlet'}

        ::Trinidad::CommandLineParser.new.load_configuration(opts)
        ::Trinidad::Server.new.start
      end

      def self.valid_options
        {
          "Host=HOST"       => "Hostname to listen on (default: localhost)",
          "Port=PORT"       => "Port to listen on (default: 8080)",
          "Threads=MIN:MAX" => "min:max threads to use (default 1:1, threadsafe)",
        }
      end
    end

    register :trinidad, Trinidad
  end
end
