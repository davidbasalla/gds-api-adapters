require 'bundler'
Bundler.setup :default, :development, :test

require 'minitest/autorun'
require 'webmock/minitest'
require 'rack/utils'
require 'simplecov'
require 'simplecov-rcov'
require 'mocha'

SimpleCov.start do
  add_filter "/test/"
  add_group "Test Helpers", "lib/gds_api/test_helpers"
  formatter SimpleCov::Formatter::RcovFormatter
end

WebMock.disable_net_connect!
