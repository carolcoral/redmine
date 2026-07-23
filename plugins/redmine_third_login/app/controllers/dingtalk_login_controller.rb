# frozen_string_literal: true

class DingtalkLoginController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]
  before_action :require_dingtalk_configured

  # 生成钉钉登录二维码
  def generate_qr_code
    appid = RedmineThirdLogin.settings['dingtalk_appid']
    
    # 生成唯一的state参数用于防止CSRF攻击
    state = SecureRandom.hex(16)
    session[:dingtalk_state] = state
    
    # 构建钉钉授权URL
    redirect_uri = dingtalk_login_callback_url(protocol: Setting.protocol)
    auth_url = "https://oapi.dingtalk.com/connect/oauth2/sns_authorize"
    
    qr_code_url = "#{auth_url}?appid=#{appid}&response_type=code&scope=snsapi_login&state=#{state}&redirect_uri=#{CGI.escape(redirect_uri)}"
    
    respond_to do |format|
      format.json { render json: { qr_code_url: qr_code_url, state: state } }
    end
  rescue => e
    Rails.logger.error "[RedmineThirdLogin] Failed to generate DingTalk QR code: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :internal_server_error }
    end
  end

  # 钉钉登录回调
  def callback
    # 验证state参数
    if params[:state] != session[:dingtalk_state]
      Rails.logger.error "[RedmineThirdLogin] Invalid state parameter in DingTalk callback"
      redirect_to signin_path, alert: l(:error_invalid_dingtalk_state)
      return
    end

    # 清理state
    session.delete(:dingtalk_state)

    # 获取临时授权码
    code = params[:code]
    if code.blank?
      Rails.logger.error "[RedmineThirdLogin] No authorization code received from DingTalk"
      redirect_to signin_path, alert: l(:error_no_dingtalk_code)
      return
    end

    # 获取用户持久授权码
    persistent_code = get_persistent_code(code)
    if persistent_code.nil?
      redirect_to signin_path, alert: l(:error_dingtalk_auth_failed)
      return
    end

    # 获取用户个人信息
    user_info = get_user_info(persistent_code)
    if user_info.nil?
      redirect_to signin_path, alert: l(:error_dingtalk_userinfo_failed)
      return
    end

    # 获取用户手机号
    mobile = user_info['mobile']
    if mobile.blank?
      Rails.logger.error "[RedmineThirdLogin] No mobile phone in DingTalk user info"
      redirect_to signin_path, alert: l(:error_no_mobile_in_dingtalk)
      return
    end

    # 根据手机号查找Redmine用户
    user = User.find_by_mobile_phone(mobile)
    if user.nil?
      Rails.logger.warn "[RedmineThirdLogin] No Redmine user found for mobile: #{mobile}"
      redirect_to signin_path, alert: l(:error_no_user_for_mobile)
      return
    end

    # 检查用户状态
    unless user.active?
      redirect_to signin_path, alert: l(:notice_account_pending)
      return
    end

    # 记录登录日志
    Rails.logger.info "[RedmineThirdLogin] User #{user.login} logged in via DingTalk with mobile #{mobile}"

    # 执行登录
    do_login(user)
  rescue => e
    Rails.logger.error "[RedmineThirdLogin] DingTalk login error: #{e.message}\n#{e.backtrace.join("\n")}"
    redirect_to signin_path, alert: l(:error_dingtalk_login_failed)
  end

  private

  # 检查钉钉配置
  def require_dingtalk_configured
    unless RedmineThirdLogin.dingtalk_enabled?
      render_404
    end
  end

  # 获取持久授权码
  def get_persistent_code(code)
    appid = RedmineThirdLogin.settings['dingtalk_appid']
    appsecret = RedmineThirdLogin.settings['dingtalk_appsecret']
    
    # 获取access_token
    token_url = "https://oapi.dingtalk.com/gettoken?appkey=#{appid}&appsecret=#{appsecret}"
    token_response = HTTParty.get(token_url)
    
    if token_response.code != 200 || token_response['access_token'].blank?
      Rails.logger.error "[RedmineThirdLogin] Failed to get DingTalk access token: #{token_response.body}"
      return nil
    end
    
    access_token = token_response['access_token']
    
    # 获取持久授权码
    persistent_code_url = "https://oapi.dingtalk.com/sns/get_persistent_code?access_token=#{access_token}"
    response = HTTParty.post(persistent_code_url, 
      body: { tmp_auth_code: code }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    
    if response.code != 200 || response['errcode'] != 0
      Rails.logger.error "[RedmineThirdLogin] Failed to get persistent code: #{response.body}"
      return nil
    end
    
    response['openid']
  rescue => e
    Rails.logger.error "[RedmineThirdLogin] Error getting persistent code: #{e.message}"
    nil
  end

  # 获取用户信息
  def get_user_info(openid)
    appid = RedmineThirdLogin.settings['dingtalk_appid']
    appsecret = RedmineThirdLogin.settings['dingtalk_appsecret']
    
    # 获取access_token
    token_url = "https://oapi.dingtalk.com/gettoken?appkey=#{appid}&appsecret=#{appsecret}"
    token_response = HTTParty.get(token_url)
    
    if token_response.code != 200 || token_response['access_token'].blank?
      Rails.logger.error "[RedmineThirdLogin] Failed to get DingTalk access token: #{token_response.body}"
      return nil
    end
    
    access_token = token_response['access_token']
    
    # 获取用户详情
    userinfo_url = "https://oapi.dingtalk.com/user/getuserinfo?access_token=#{access_token}&code=#{openid}"
    response = HTTParty.get(userinfo_url)
    
    if response.code != 200 || response['errcode'] != 0
      Rails.logger.error "[RedmineThirdLogin] Failed to get user info: #{response.body}"
      return nil
    end
    
    # 获取完整的用户信息
    user_id = response['userid']
    if user_id.present?
      detail_url = "https://oapi.dingtalk.com/user/get?access_token=#{access_token}&userid=#{user_id}"
      detail_response = HTTParty.get(detail_url)
      
      if detail_response.code == 200 && detail_response['errcode'] == 0
        return detail_response
      end
    end
    
    response
  rescue => e
    Rails.logger.error "[RedmineThirdLogin] Error getting user info: #{e.message}"
    nil
  end

  # 执行登录
  def do_login(user)
    # 设置session
    session[:user_id] = user.id
    session[:tk] = user.generate_session_token
    
    # 更新用户登录信息
    user.update_column(:last_login_on, Time.now)
    
    # 设置cookies
    if params[:autologin].present?
      token = Token.create!(user: user, action: 'autologin')
      cookie_options = {
        value: token.value,
        expires: 1.year.from_now,
        httponly: true,
        same_site: :lax
      }
      cookie_options[:secure] = true if Setting.protocol == 'https'
      cookies[:autologin] = cookie_options
    end
    
    # 重定向到首页或原始请求页面
    redirect_to (session[:redirect_to] || home_url)
    session.delete(:redirect_to)
  end
end
