require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Trinidad::Logging do
  include FakeApp
  
  JUL = Java::JavaUtilLogging
  
  before do
    @root_logger = JUL::Logger.getLogger('')
    @root_level = @root_logger.level
    @root_handlers = @root_logger.handlers.to_a
    
    Trinidad::Logging.send :class_variable_set, :@@configured, nil
  end
  
  after do
    @root_logger.level = @root_level # JUL::Level::INFO
    @root_logger.handlers.each { |handler| @root_logger.removeHandler(handler) }
    @root_handlers.each { |handler| @root_logger.addHandler(handler) }    
  end
  
  it "configures logging during server creation" do
    Trinidad::Server.new({ :log => 'WARNING', :root_dir => MOCK_WEB_APP_DIR })
    
    logger = JUL::Logger.getLogger('')
    logger.level.name.should.== 'WARNING'
    logger.handlers.size.should == 2
  end
  
  after { Trinidad.configuration = nil }

  it "uses the specified log level when it's valid" do
    Trinidad::Logging.configure!('WARNING')

    logger = java.util.logging.Logger.getLogger("")
    logger.level.to_s.should == 'WARNING'
    
    Trinidad::Logging.configure!('DEBUG')

    logger = java.util.logging.Logger.getLogger("")
    logger.level.to_s.should == 'FINE'
  end

  it "uses INFO as default log level when it's invalid" do
    Trinidad::Logging.configure!('FOO')

    logger = java.util.logging.Logger.getLogger("")
    logger.level.to_s.should == 'INFO'
  end

  it "does not reconfigure twice if not forced ..." do
    Trinidad::Logging.configure!('WARNING')
    Trinidad::Logging.configure('SEVERE')

    logger = java.util.logging.Logger.getLogger("")
    logger.level.to_s.should == 'WARNING'
  end
  
  # web-app logger configuration :
  
  context "web-app" do
    
    let(:tomcat) { org.apache.catalina.startup.Tomcat.new }
    let(:context) { Trinidad::Tomcat::StandardContext.new }
    
    before { FileUtils.rm Dir.glob("#{MOCK_WEB_APP_DIR}/log/*") }
    after do 
      tomcat.stop if tomcat.server.state_name =~ /START/i
    end
    
    it "configures from provided logging configuration" do
      make_file log_file = "#{MOCK_WEB_APP_DIR}/log/production.txt", "previous-content\n"
      yesterday = Time.now - 60 * 60 * 24
      java.io.File.new(log_file).setLastModified(yesterday.to_f * 1000)
      
      web_app = create_mock_web_app :context_path => '/app0', 
        :logging => {
          :level => 'debug', :format => 'dd.MM -',
          :file => { 
            :rotate => false, 
            :suffix => '.txt', 
            :directory => 'log', 
            :buffer_size => 4096
          }
        }
      context = create_mock_web_app_context web_app
      
      logger = Trinidad::Logging.configure_web_app(web_app, context)
      logger.fine "hello-there"
      
      File.exist?(log_file).should be true; now = Time.now
      
      File.read(log_file).should == "previous-content\n"
       
      logger.handlers.first.flush
      File.read(log_file).should == "previous-content\n" + 
         "#{format('%02d', now.day)}.#{format('%02d', now.month)} - FINE: hello-there\n"
    end
    
    it "creates the log file according with the environment if it doesn't exist" do
      web_app = create_mock_web_app :context_path => '/app1'
      context = create_mock_web_app_context web_app
      #context.start
      
      logger = Trinidad::Logging.configure_web_app(web_app, context)
      logger.info "hello world!" # file creation might be lazy ...
      
      File.exist?(File.join(MOCK_WEB_APP_DIR, 'log', 'production.log')).should be true
      Dir.glob("#{MOCK_WEB_APP_DIR}/log/*").size.should == 1
    end

    it "appends the log file if it exists" do
      File.open("#{MOCK_WEB_APP_DIR}/log/production.log", 'w') { |f| f << "42\n" }
      
      web_app = create_mock_web_app :context_path => '/app2'
      context = create_mock_web_app_context web_app
      #context.start
      
      logger = Trinidad::Logging.configure_web_app(web_app, context)
      logger.warning "watch out!" # file creation might be lazy ...
      
      log_content = File.read("#{MOCK_WEB_APP_DIR}/log/production.log")
      
      log_content[0, 3].should == "42\n"
      log_content[3..-1].should =~ /.*?WARNING.*?watch out!$/
    end
    
    it "rotates an old log file" do
      File.open("#{MOCK_WEB_APP_DIR}/log/staging.log", 'w') { |f| f << "old entry\n" }
      yesterday = Time.now - 60 * 60 * 24; yesterday_ms = yesterday.to_f * 1000
      java.io.File.new("#{MOCK_WEB_APP_DIR}/log/staging.log").setLastModified(yesterday_ms)
      
      web_app = create_mock_web_app :context_path => '/app3', :environment => 'staging'
      context = create_mock_web_app_context web_app
      #context.start
      
      logger = Trinidad::Logging.configure_web_app(web_app, context)
      logger.warning "watch out!" # file creation might be lazy ...
      
      log_content = File.read("#{MOCK_WEB_APP_DIR}/log/staging.log")
      
      log_content[0, 3].should_not == "old"
      log_content.should =~ /.*?WARNING.*?watch out!$/
      
      y_date = yesterday.strftime '%Y-%m-%d'
      File.exist?("#{MOCK_WEB_APP_DIR}/log/staging#{y_date}.log").should be true
      File.read("#{MOCK_WEB_APP_DIR}/log/staging#{y_date}.log").should == "old entry\n"
    end
    
    it "rotates and merges an old log file" do
      make_file "#{MOCK_WEB_APP_DIR}/log/staging.log", "old entry\n"
      yesterday = Time.now - 60 * 60 * 24; yesterday_ms = yesterday.to_f * 1000
      y_date = yesterday.strftime '%Y-%m-%d'
      java.io.File.new("#{MOCK_WEB_APP_DIR}/log/staging.log").setLastModified(yesterday_ms)
      File.open("#{MOCK_WEB_APP_DIR}/log/staging#{y_date}.log", 'w') { |f| f << "very old entry\n" }
      
      web_app = create_mock_web_app :context_path => '/app4', :environment => 'staging'
      context = create_mock_web_app_context web_app
      #context.start
      
      logger = Trinidad::Logging.configure_web_app(web_app, context)
      logger.warning "me-he-he-he" # file creation might be lazy ...
      
      File.exist?("#{MOCK_WEB_APP_DIR}/log/staging#{y_date}.log").should be true
      File.read("#{MOCK_WEB_APP_DIR}/log/staging#{y_date}.log").should == "very old entry\nold entry\n"
    end
    
    org.apache.juli.FileHandler.class_eval do
      field_accessor :date
    end
    
    it "rotates when logging date changes" do
      make_file "#{MOCK_WEB_APP_DIR}/log/production.log", "old entry\n"
      yesterday = Time.now - 60 * 60 * 24; yesterday_ms = yesterday.to_f * 1000
      java.io.File.new("#{MOCK_WEB_APP_DIR}/log/production.log").setLastModified(yesterday_ms)
      
      web_app = create_mock_web_app :context_path => '/app5'
      context = create_mock_web_app_context web_app
      #context.start
      
      logger = Trinidad::Logging.configure_web_app(web_app, context)
      file_handler = logger.handlers.find { |handler| handler.is_a?(org.apache.juli.FileHandler) }
      file_handler.date = yesterday.strftime '%Y-%m-%d' # FileHandler internals
      file_handler.open # make sure file is open (smt was logged previously)
      logger.warning "watch out!" # should switch to today
      
      log_content = File.read("#{MOCK_WEB_APP_DIR}/log/production.log")
      
      log_content[0, 3].should_not == "old"
      log_content.should =~ /.*?WARNING.*?watch out!$/
      
      y_date = yesterday.strftime '%Y-%m-%d'
      File.exist?("#{MOCK_WEB_APP_DIR}/log/production#{y_date}.log").should be true
      File.read("#{MOCK_WEB_APP_DIR}/log/production#{y_date}.log").should == "old entry\n"
    end
    
    it 'uses same logger as ServletContext#log by default (unless logger name specified)' do
      web_app = create_mock_web_app :environment => 'staging', :context_path => '/foo'
      context = create_mock_web_app_context web_app
      #context.start

      logger = Trinidad::Logging.configure_web_app(web_app, context)
      
      context.getServletContext.log "szia!"
      context.getServletContext.log "hola!", java.lang.RuntimeException.new
      
      log_content = File.read("#{MOCK_WEB_APP_DIR}/log/staging.log")
      log_content.split("\n")[0].should =~ /^.*?INFO: szia!/
      log_content.split("\n")[1].should =~ /^.*?SEVERE: hola!/
      log_content.split("\n")[2..-1].join("\n").should =~ /java\.lang\.RuntimeException.*?/
    end
    
    it "configures application logging once" do
      web_app = create_mock_web_app :environment => 'staging', :context_path => '/bar'
      context = create_mock_web_app_context web_app
      #context.start

      logger = Trinidad::Logging.configure_web_app(web_app, context)
      handlers = logger.handlers.to_a

      Trinidad::Logging.configure_web_app(web_app, context).should be false
      JUL::Logger.getLogger(logger.name).handlers.to_a.should == handlers
    end

    it "delegates logs to console (root logger) in development" do
      web_app = create_mock_web_app :environment => 'development', :context_path => '/foo2'
      context = create_mock_web_app_context web_app
      #context.start
      Trinidad::Logging.configure_web_app(web_app, context)
      
      root_logger = JUL::Logger.getLogger('')
      output = java.io.ByteArrayOutputStream.new
      #root_logger.handlers.to_a.each do |handler|
      #  root_logger.removeHandler(handler) if handler.is_a?(JUL::ConsoleHandler)
      #end
      handler = JUL::StreamHandler.new
      handler.setOutputStream(output)
      handler.formatter = org.apache.juli.VerbatimFormatter.new
      root_logger.addHandler(handler)

      context.logger.info 'hello there 1' # a Log instance
      logger = JUL::Logger.getLogger(context.send(:logName))
      logger.warning 'red alert 1'

      handler.flush

      output.toString.split("\n")[0].should == 'hello there 1'
      output.toString.split("\n")[1].should == 'red alert 1'
    end

    it "does not delegate logs to console (root logger) in non-development" do
      web_app = create_mock_web_app :environment => 'staging', :context_path => '/foo3'
      context = create_mock_web_app_context web_app
      #context.start
      Trinidad::Logging.configure_web_app(web_app, context)
      
      root_logger = JUL::Logger.getLogger('')
      output = java.io.ByteArrayOutputStream.new
      handler = JUL::StreamHandler.new
      handler.setOutputStream(output)
      handler.formatter = org.apache.juli.VerbatimFormatter.new
      root_logger.addHandler(handler)

      context.logger.info 'hello there 2' # a Log instance
      logger = JUL::Logger.getLogger(context.send(:logName))
      logger.warning 'red alert 2'

      handler.flush

      output.toString.should == ''
    end

    it "does not configure logger if descriptor specified non JUL logging" do
      FileUtils.touch custom_web_xml = "#{MOCK_WEB_APP_DIR}/config/logging-test.web.xml"
      begin
        create_config_file custom_web_xml, '' +
          '<?xml version="1.0" encoding="UTF-8"?>' +
          '<web-app>' +
          '  <context-param>' +
          '    <param-name>jruby.rack.logging</param-name>' +
          '    <param-value>stdout</param-value>' +
          '  </context-param>' +
          '</web-app>'
        web_app = Trinidad::WebApp.create({}, {
          :context_path => '/',
          :web_app_dir => MOCK_WEB_APP_DIR,
          :default_web_xml => 'config/logging-test.web.xml',
          :log => 'ALL'
        })
        context = create_mock_web_app_context web_app
        context.setDefaultWebXml web_app.default_deployment_descriptor
        
        outcome = Trinidad::Logging.configure_web_app(web_app, context)
        outcome.should be nil
      ensure
        FileUtils.rm custom_web_xml
      end
    end
    
    it "accepts configured logger name (from descriptor)", :integration => true do
      FileUtils.touch custom_web_xml = "#{MOCK_WEB_APP_DIR}/config/logging-test.web.xml"
      begin
        create_config_file custom_web_xml, '' +
          '<?xml version="1.0" encoding="UTF-8"?>' +
          '<web-app>' +
          '  <context-param>' +
          '    <param-name>jruby.rack.logging.name</param-name>' +
          '    <param-value>MyApp.Logger.Name</param-value>' +
          '  </context-param>' +
          '</web-app>'
        web_app = Trinidad::WebApp.create({}, {
          :context_path => '/',
          :web_app_dir => MOCK_WEB_APP_DIR,
          :default_web_xml => 'config/logging-test.web.xml',
          :log => 'ALL'
        })
        context = create_mock_web_app_context web_app
        context.setDefaultWebXml web_app.default_deployment_descriptor
        context.start
        
        Trinidad::Logging.configure_web_app(web_app, context)

        log_manager = JUL::LogManager.getLogManager
        log_manager.getLoggerNames.to_a.should include('MyApp.Logger.Name')
        
        app_logger = JUL::Logger.getLogger('MyApp.Logger.Name')
        app_logger.level.to_s.should == 'ALL'
      ensure
        FileUtils.rm custom_web_xml
      end
    end
    
    it "logs with a Rails application via Rails.logger", :integration => true do
      FileUtils.rm Dir.glob("#{RAILS_WEB_APP_DIR}/log/*")
      FileUtils.touch logging_test_rb = "#{RAILS_WEB_APP_DIR}/config/initializers/logging_test.rb"
      begin
        File.open(logging_test_rb, 'w') do |f| 
          f << "Rails.logger.debug 'this should not be logged on production'\n"
          f << "Rails.logger.info 'this should be logged ...'\n"
        end
        
        web_app = Trinidad::WebApp.create({}, { 
            :context_path => '/rails', 
            :web_app_dir => RAILS_WEB_APP_DIR, 
            :environment => 'production' }
        )
        context = create_web_app_context(RAILS_WEB_APP_DIR, web_app)
        context.start
        
        log_content = File.read("#{RAILS_WEB_APP_DIR}/log/production.log")
        # [jruby-rack] production.rb is config.threadsafe! :
        log_content.should =~ /using a shared \(threadsafe!\) runtime/
        log_content.should =~ /INFO: this should be logged .../
        log_content.should_not =~ /this should not be logged on production/
      ensure
        FileUtils.rm logging_test_rb
      end
    end
    
    private
    
    def create_mock_web_app(config = {})
      Trinidad::WebApp.create({}, { 
          :context_path => '/', 
          :web_app_dir => MOCK_WEB_APP_DIR, 
          :environment => 'production' }.merge(config)
      )
    end
    
    def create_mock_web_app_context(web_app)
      context = create_web_app_context(MOCK_WEB_APP_DIR, web_app)
      context.loader = org.apache.catalina.loader.WebappLoader.new
      context
    end

    def create_web_app_context(context_dir, web_app)
      context_path = web_app.context_path
      context = tomcat.addWebapp(context_path, context_dir)
      context.addLifecycleListener web_app.define_lifecycle
      context
    end
    
    def make_file(path, content = nil)
      if dir = File.dirname(path)
        FileUtils.mkdir(dir) unless File.exist?(dir)
      end
      FileUtils.touch path
      File.open(path, 'w') { |f| f << content } if content
    end
    
  end
  
  describe 'FileHandler' do
    
    FileHandler = Trinidad::Logging::FileHandler
    
    let(:prefix) { 'testing' }
    let(:suffix) { '.log' }
    let(:log_dir) { "#{MOCK_WEB_APP_DIR}/log" }
    let(:log_file) { "#{log_dir}/#{prefix}#{suffix}" }
    
    before { FileUtils.touch log_file }
    after { FileUtils.rm log_file if File.exist?(log_file) }
    
    it 'logs when rotatable' do
      file_handler = FileHandler.new(log_dir, prefix, suffix)
      file_handler.rotatable = true # {prefix}{date}{suffix}

      log_content = File.read(log_file)
      log_content.should_not =~ /sample log entry/
        
      file_handler.publish new_log_record('sample log entry')

      log_content = File.read(log_file)
      log_content.should =~ /sample log entry/
    end
    
    it 'logs when non-rotatable' do
      file_handler = FileHandler.new(log_dir, prefix, suffix)
      file_handler.rotatable = false # {prefix}{suffix}

      log_content = File.read(log_file)
      log_content.should_not =~ /another log entry/
        
      file_handler.publish new_log_record('another log entry')

      log_content = File.read(log_file)
      log_content.should =~ /another log entry/
    end
    
    private
    
    def new_log_record(options = {})
      if options.is_a?(String)
        message = options; options = {}
      else
        message = options[:message] || '42'
      end
      time = options[:time]
      level = JUL::Level::WARNING
      record = JUL::LogRecord.new level, message
      record.millis = time.to_java.time if time
      record
    end
    
  end
  
end

describe Trinidad::Logging::DefaultFormatter do
  
  it "formats time (according to local time zone)" do
    time = Time.local(2011, 2, 5, 13, 45, 22)
    record = JUL::LogRecord.new JUL::Level::WARNING, nil
    record.message = 'Nyan nyan nyan!'
    record.millis = time.to_java.time
    
    formatter = new_formatter("yyyy-MM-dd HH:mm:ss Z")
    offset = time_offset(time)
    formatter.format(record).should == "2011-02-05 13:45:22 #{offset} WARNING: Nyan nyan nyan!\n"
  end
  
  it "formats time (according to UTC time zone)" do
    time = Time.utc(2011, 2, 5, 13, 45, 22)
    record = JUL::LogRecord.new JUL::Level::INFO, "basza meg a zold tucsok"
    record.millis = time.to_java.time
    
    formatter = new_formatter("yyyy-MM-dd HH:mm:ss Z", 0)
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 INFO: basza meg a zold tucsok\n"
    
    formatter = new_formatter("yyyy-MM-dd HH:mm:ss Z", 'GMT')
    formatter.format(record).should == "2011-02-05 13:45:22 +0000 INFO: basza meg a zold tucsok\n"
  end

  it "does not add new line to message if already present" do
    record = JUL::LogRecord.new JUL::Level::INFO, msg = "basza meg a zold tucsok\n"
    record.millis = java.lang.System.current_time_millis
    
    formatter = new_formatter 'yyyy-MM-dd HH:mm:ss Z'
    log_msg = formatter.format(record)
    log_msg[-(msg.size + 6)..-1].should == "INFO: basza meg a zold tucsok\n"
  end
  
  it "prints thrown exception if present" do
    record = JUL::LogRecord.new JUL::Level::SEVERE, nil
    record.message = "Bazinga!"
    record.thrown = java.lang.RuntimeException.new("42")
    
    formatter = new_formatter 'yyyy-MM-dd HH:mm:ss Z'
    formatter.format(record).should =~ /.*? SEVERE: Bazinga!\n/
    lines = formatter.format(record).split("\n")
    lines[1].should == 'java.lang.RuntimeException: 42'
    lines.size.should > 3
    lines[2...-1].each { |line| line.should =~ /at .*?(.*?)/ } # at org.jruby.RubyProc.call(RubyProc.java:270)
  end
  
  private
  
  def new_formatter(*args)
    Trinidad::Logging::DefaultFormatter.new(*args)
  end
  
  def time_offset(time)
    offset = time.utc_offset / 3600
    format "%+03d%02d", offset, (offset * 100) % 100
  end
  
end

describe Trinidad::Logging::MessageFormatter do

  it "logs message (adding a new line)" do
    record = JUL::LogRecord.new JUL::Level::SEVERE, nil
    record.message = "Bazinga!"
    
    new_formatter.format(record).should == "Bazinga!\n"
  end
  
  it "does not add new line to message for application logger if present" do
    record = JUL::LogRecord.new JUL::Level::INFO, msg = "basza meg a zold tucsok\n"
    record.millis = java.lang.System.current_time_millis
    record.logger_name = 'org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/]'
    
    new_formatter.format(record).should == "basza meg a zold tucsok\n"
    
    record.logger_name = 'org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[default]'
    record.message = "azt a kutya fajat!\n"
    
    new_formatter.format(record).should == "azt a kutya fajat!\n"
    
    #
    
    record.logger_name = 'org.apache.catalina.core.ContainerBase'
    
    new_formatter.format(record).should == "azt a kutya fajat!\n\n"
  end

  it "adds new line for every message if missing" do
    record = JUL::LogRecord.new JUL::Level::INFO, msg = "basza meg a zold tucsok"
    record.millis = java.lang.System.current_time_millis
    record.logger_name = 'org.apache.catalina.core.ContainerBase.[Tomcat].[localhost].[/foo]'
    
    new_formatter.format(record).should == "basza meg a zold tucsok\n"
    
    record.logger_name = 'org.apache.catalina.core.ContainerBase'
    record.message = "azt a kutya fajat!\n"
    
    new_formatter.format(record).should == "azt a kutya fajat!\n\n"
  end
  
  it "prints thrown exception if present" do
    record = JUL::LogRecord.new JUL::Level::SEVERE, nil
    record.message = "Bazinga!"
    record.thrown = java.lang.RuntimeException.new("42")
    
    formatter = new_formatter
    formatter.format(record).should =~ /Bazinga!\n/
    lines = formatter.format(record).split("\n")
    lines[1].should == 'java.lang.RuntimeException: 42'
    lines.size.should > 3
    lines[2...-1].each { |line| line.should =~ /at .*?(.*?)/ } # at org.jruby.RubyProc.call(RubyProc.java:270)
  end
  
  private
  
  def new_formatter
    Trinidad::Logging::MessageFormatter.new
  end
  
end

describe "Trinidad::LogFormatter" do
  it "still works" do
    Trinidad::LogFormatter.should == Trinidad::Logging::DefaultFormatter
  end
end
