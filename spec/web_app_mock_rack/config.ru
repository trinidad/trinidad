require 'rubygems'
require 'rack'

run lambda { |env| [ 200, { "Content-Type" => "text/plain" }, "Greetings!" ] }
