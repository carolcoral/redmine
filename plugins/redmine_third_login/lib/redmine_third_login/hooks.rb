# frozen_string_literal: true

module RedmineThirdLogin
  module Hooks
    class ViewListener < Redmine::Hook::ViewListener
      # 在登录页面头部添加CSS和JavaScript
      def view_layouts_base_html_head(context = {})
        return unless context[:controller].is_a?(AccountController)
        
        # 加载插件JavaScript和CSS
        plugin_js = javascript_include_tag('redmine_third_login', plugin: 'redmine_third_login')
        plugin_css = stylesheet_link_tag('redmine_third_login', plugin: 'redmine_third_login')
        
        plugin_js + plugin_css
      end

      # 在登录表单底部（按钮上方）添加登录方式选择器
      def view_account_login_bottom(context = {})
        return unless context[:controller].is_a?(AccountController)
        
        enabled_types = RedmineThirdLogin.enabled_login_types
        return '' if enabled_types.size <= 1
        
        context[:controller].send(:render_to_string, 
          partial: 'account/login_type_selector',
          locals: { enabled_types: enabled_types }
        )
      end
    end
  end
end
