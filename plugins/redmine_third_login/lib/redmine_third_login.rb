# frozen_string_literal: true

require File.expand_path('redmine_third_login/hooks', __dir__)
require File.expand_path('redmine_third_login/user_patch', __dir__)

module RedmineThirdLogin
  PLUGIN_NAME = 'redmine_third_login'
  PLUGIN_VERSION = '1.0.0'

  # 获取插件设置
  def self.settings
    Setting.plugin_redmine_third_login || {}
  end

  # 检查是否启用钉钉登录
  def self.dingtalk_enabled?
    settings['enabled_login_types'].include?('dingtalk') && 
    settings['dingtalk_appid'].present? && 
    settings['dingtalk_appsecret'].present?
  end

  # 检查是否启用LDAP登录
  def self.ldap_enabled?
    AuthSource.where(type: 'AuthSourceLdap').exists? && 
    settings['enabled_login_types'].include?('ldap')
  end

  # 获取启用的登录方式
  def self.enabled_login_types
    types = []
    types << 'local' if settings['enabled_login_types'].include?('local')
    types << 'ldap' if ldap_enabled?
    types << 'dingtalk' if dingtalk_enabled?
    types
  end
end
