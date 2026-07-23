# frozen_string_literal: true

module DingtalkLoginHelper
  # 检查是否启用了钉钉登录
  def dingtalk_login_enabled?
    RedmineThirdLogin.dingtalk_enabled?
  end

  # 生成钉钉登录按钮HTML
  def dingtalk_login_button
    return '' unless dingtalk_login_enabled?
    
    content_tag(:div, id: 'dingtalk-login-container', class: 'dingtalk-login-container') do
      content_tag(:div, '', id: 'dingtalk-qr-code', class: 'dingtalk-qr-code') +
      content_tag(:div, '', id: 'dingtalk-login-status', class: 'dingtalk-login-status')
    end
  end

  # 获取钉钉配置
  def dingtalk_config
    {
      appid: RedmineThirdLogin.settings['dingtalk_appid'],
      redirect_uri: dingtalk_login_callback_url(protocol: Setting.protocol),
      generate_qr_code_url: generate_qr_code_dingtalk_login_index_url
    }
  end
end
