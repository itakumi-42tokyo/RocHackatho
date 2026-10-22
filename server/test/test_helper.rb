ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # 時間を進めるテスト（期限切れなど）で使う
    include ActiveSupport::Testing::TimeHelpers
  end
end
