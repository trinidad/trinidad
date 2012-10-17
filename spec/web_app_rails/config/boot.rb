require 'rubygems'

# Set up gems listed in the Gemfile.
# ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
# NOTE: use Trinidad's Gemfile - we'll require the integration group
# @see #application.rb Bundler.require(:integration, Rails.env)
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
