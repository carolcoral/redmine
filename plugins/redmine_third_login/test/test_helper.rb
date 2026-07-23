# frozen_string_literal: true

# Redmine Third Login Plugin - Test Helper
# Author: carolcoral

require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/db/'
end

ENV['RAILS_ENV'] = 'test'

# Load Redmine test helper
require File.expand_path('../../../test/test_helper', __dir__)

# Load plugin
require File.expand_path('../init', __dir__)

module RedmineThirdLogin
  module TestHelper
    # Setup test environment for plugin
    def setup_plugin_test
      @user = User.find(1) # Admin user
      @setting = Setting.plugin_redmine_third_login
    end

    # Create test user with mobile phone
    def create_user_with_mobile(options = {})
      user = User.generate!(options)
      
      # Add mobile phone custom field if not exists
      custom_field = UserCustomField.find_by(name: '手机号')
      unless custom_field
        custom_field = UserCustomField.create!(
          name: '手机号',
          field_format: 'string',
          is_required: false
        )
      end
      
      # Set mobile phone value
      user.custom_field_values = { custom_field.id => options[:mobile] || '13800138000' }
      user.save!
      
      user
    end

    # Mock DingTalk API responses
    def mock_dingtalk_responses
      # Mock access token response
      access_token_response = {
        'errcode' => 0,
        'errmsg' => 'ok',
        'access_token' => 'mock_access_token_12345'
      }.to_json

      # Mock user info response
      user_info_response = {
        'errcode' => 0,
        'errmsg' => 'ok',
        'userid' => 'mock_user_id',
        'name' => 'Test User',
        'mobile' => '13800138000'
      }.to_json

      # Mock persistent code response
      persistent_code_response = {
        'errcode' => 0,
        'errmsg' => 'ok',
        'openid' => 'mock_openid_12345',
        'persistent_code' => 'mock_persistent_code_12345'
      }.to_json

      {
        access_token: access_token_response,
        user_info: user_info_response,
        persistent_code: persistent_code_response
      }
    end

    # Configure plugin settings for tests
    def configure_plugin_settings(overrides = {})
      default_settings = {
        'dingtalk_appid' => 'test_app_id',
        'dingtalk_appsecret' => 'test_app_secret',
        'enabled_login_types' => ['local', 'ldap', 'dingtalk']
      }
      
      settings = default_settings.merge(overrides)
      Setting.plugin_redmine_third_login = settings
      settings
    end
  end
end

# Make test helper available to all tests
ActiveSupport::TestCase.include(RedmineThirdLogin::TestHelper)
