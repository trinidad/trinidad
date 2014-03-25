require 'rubygems'
require 'sinatra'

get '/' do
  "You have been SERVED!"
end

run Sinatra::Application
