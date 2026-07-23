# frozen_string_literal: true

require File.expand_path('../../test_helper', __dir__)

# Integration test for DingTalk login flow
# 钉钉登录流程集成测试
class DingtalkLoginFlowTest < ActionDispatch::IntegrationTest
  fixtures :users, :email_addresses

  setup do
    # Configure plugin for testing
    configure_plugin_settings
    
    # Create mobile custom field
    @mobile_field = UserCustomField.find_or_create_by!(name: '手机号') do |f|
      f.field_format = 'string'
      f.is_required = false
    end
    
    # Setup test user with mobile
    @user = create_user_with_mobile(
      login: 'dingtalk_user',
      mail: 'dingtalk@example.com',
      mobile: '13800138000'
    )
  end

  teardown do
    # Clean up
    Setting.plugin_redmine_third_login = {}
  end

  test "plugin should be properly loaded" do
    get '/login'
    assert_response :success
    assert_select 'div.login-type-selector', count: 1
  end

  test "login type selector should show when multiple types enabled" do
    get '/login'
    assert_response :success
    
    # Should have login type selector
    assert_select 'select#login-type-select' do
      assert_select 'option[value=?]', 'local'
      assert_select 'option[value=?]', 'dingtalk'
    end
  end

  test "dingtalk qr code container should be present when dingtalk enabled" do
    get '/login'
    assert_response :success
    
    # Should have dingtalk container
    assert_select 'div#dingtalk-login-container'
    assert_select 'div#dingtalk-qr-code'
  end

  test "should generate qr code when dingtalk selected" do
    # Mock the controller action
    DingtalkLoginController.any_instance.expects(:generate_qr_code).returns({
      qr_code_url: 'https://oapi.dingtalk.com/connect/oauth2/sns_authorize?appid=test',
      state: 'test_state'
    })
    
    post '/dingtalk_login/generate_qr_code', xhr: true
    assert_response :success
  end

  test "should handle dingtalk callback successfully" do
    # Mock successful DingTalk API responses
    mock_response = mock_dingtalk_responses
    
    HTTParty.expects(:get).returns(stub(code: 200, body: mock_response[:access_token]))
    HTTParty.expects(:post).returns(stub(code: 200, body: mock_response[:persistent_code]))
    HTTParty.expects(:get).returns(stub(code: 200, body: mock_response[:user_info]))
    
    # Set session state
    open_session do |session|
      session[:dingtalk_state] = 'test_state'
    end
    
    # Simulate callback from DingTalk
    get '/dingtalk_login/callback', params: {
      code: 'test_auth_code',
      state: 'test_state'
    }
    
    # Should redirect to home page
    assert_redirected_to '/'
    
    # Should be logged in
    assert_equal @user.id, session[:user_id]
  end

  test "should handle user not found error" do
    # Mock API responses with non-existent mobile
    mock_response = mock_dingtalk_responses
    user_info = JSON.parse(mock_response[:user_info])
    user_info['mobile'] = '99999999999' # Non-existent mobile
    
    HTTParty.expects(:get).returns(stub(code: 200, body: { 'access_token' => 'test' }.to_json))
    HTTParty.expects(:post).returns(stub(code: 200, body: { 'openid' => 'test' }.to_json))
    HTTParty.expects(:get).returns(stub(code: 200, body: user_info.to_json))
    
    open_session do |session|
      session[:dingtalk_state] = 'test_state'
    end
    
    get '/dingtalk_login/callback', params: {
      code: 'test_code',
      state: 'test_state'
    }
    
    # Should redirect to login with error
    assert_redirected_to '/login'
    assert_match /未找到与此手机号匹配的Redmine用户/, flash[:alert]
  end

  test "should handle invalid state parameter" do
    get '/dingtalk_login/callback', params: {
      code: 'test_code',
      state: 'invalid_state'
    }
    
    assert_redirected_to '/login'
    assert_match /无效的登录状态/, flash[:alert]
  end

  test "should handle missing authorization code" do
    open_session do |session|
      session[:dingtalk_state] = 'test_state'
    end
    
    get '/dingtalk_login/callback', params: {
      state: 'test_state'
      # No code parameter
    }
    
    assert_redirected_to '/login'
    assert_match /未收到钉钉的授权码/, flash[:alert]
  end

  test "plugin settings should be accessible" do
    settings = RedmineThirdLogin.settings
    assert_not_nil settings
    assert_equal 'test_app_id', settings['dingtalk_appid']
    assert_equal ['local', 'ldap', 'dingtalk'], settings['enabled_login_types']
  end

  test "dingtalk enabled check should work" do
    assert RedmineThirdLogin.dingtalk_enabled?
    
    # Disable dingtalk
    Setting.plugin_redmine_third_login = {
      'dingtalk_appid' => '',
      'dingtalk_appsecret' => ''
    }
    
    assert_not RedmineThirdLogin.dingtalk_enabled?
  end

  test "user mobile phone method should work" do
    # Set mobile phone value
    custom_value = CustomValue.create!(
      customized: @user,
      custom_field: @mobile_field,
      value: '13800138000'
    )
    
    @user.reload
    assert_equal '13800138000', @user.mobile_phone
  end

  test "find user by mobile phone should work" do
    # Set mobile phone value
    CustomValue.create!(
      customized: @user,
      custom_field: @mobile_field,
      value: '13800138000'
    )
    
    found_user = User.find_by_mobile_phone('13800138000')
    assert_equal @user.id, found_user.id
    
    # Test non-existent mobile
    not_found = User.find_by_mobile_phone('99999999999')
    assert_nil not_found
  end

  test "should respect enabled login types" do
    # Only local login
    configure_plugin_settings('enabled_login_types' => ['local'])
    
    get '/login'
    assert_response :success
    
    # Should not show login type selector when only one type
    assert_select 'div.login-type-selector', count: 0
    assert_select 'select#login-type-select', count: 0
  end
end
