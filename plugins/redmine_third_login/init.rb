# frozen_string_literal: true

require 'redmine'

Redmine::Plugin.register :redmine_third_login do
  name 'Redmine Third Login Plugin'
  author 'carolcoral'
  description 'Redmine登录方式扩展插件，支持本地登录、LDAP登录和钉钉扫码登录。详细文档：https://github.com/carolcoral/redmine_third_login'
  version '1.0.0'
  url 'https://github.com/carolcoral/redmine_third_login'
  author_url 'https://github.com/carolcoral'

  # 插件设置
  settings(
    default: {
      'dingtalk_appid' => '',
      'dingtalk_appsecret' => '',
      'enabled_login_types' => ['local', 'ldap', 'dingtalk']
    },
    partial: 'settings/redmine_third_login_settings'
  )
end

# 加载插件文件
require_relative 'lib/redmine_third_login'
require_relative 'app/controllers/dingtalk_login_controller'
require_relative 'app/helpers/dingtalk_login_helper'

# 在Redmine启动后执行的代码
Rails.application.config.after_initialize do
  # 确保User模型已加载
  User.send(:include, RedmineThirdLogin::UserPatch) if User.included_modules.exclude?(RedmineThirdLogin::UserPatch)
end
