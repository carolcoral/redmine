require 'redmine'

Redmine::Plugin.register :redmine_logo do
  name 'Redmine Logo Plugin'
  author 'carolcoral'
  description 'Customizable logo plugin for Redmine 6.1.x with support for text or image logo in top menu area, custom head content insertion, and more'
  version '1.0.3'
  url 'https://github.com/carolcoral/redmine_logo'
  author_url 'https://github.com/carolcoral'

  requires_redmine version_or_higher: '6.1.0'

  settings default: {
    'plugin_enabled' => '1',  # 插件启用开关
    'logo_type' => 'text',
    'logo_text' => 'Redmine',
    'logo_text_color' => '#ffffff',
    'logo_first_letter_color' => '#ff6600',  # 首字母颜色
    'logo_text_font_size' => '26px',  # 固定字体大小为26px
    'logo_text_font_weight' => '600',
    'logo_position' => 'left',
    'logo_image_base64' => '',  # base64编码的图片数据
    'logo_image_content_type' => '',  # 图片content type
    'logo_margin' => '0',
    'logo_padding' => '8px',
    'logo_height' => '25px',  # Logo高度
    'custom_system_url' => '',  # 自定义系统访问地址
    'custom_head_content' => ''  # 自定义<head>内容
  }, partial: 'logo_settings/form'

  # 不注册独立的管理菜单项，配置通过“管理 → 插件 → Redmine Logo Plugin → 配置”进入
end

require_relative 'lib/redmine_logo/view_listener'
require_relative 'lib/redmine_logo/system_url_override'
require_relative 'app/helpers/logo_helper'

# 应用系统URL覆盖（如果已配置）
RedmineLogo::SystemUrlOverride.apply!
