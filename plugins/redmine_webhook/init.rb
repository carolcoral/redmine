require 'redmine'

# 获取插件根目录
plugin_root = File.dirname(__FILE__)

# 配置 Zeitwerk 忽略某些文件
# 防止自动加载诊断和测试文件
if defined?(Rails::Autoloaders)
  Rails.autoloaders.main.ignore(File.join(plugin_root, 'lib', 'tasks', 'test_*.rake'))
  Rails.autoloaders.main.ignore(File.join(plugin_root, 'lib', 'tasks', 'diagnose*.rake'))
  Rails.autoloaders.main.ignore(File.join(plugin_root, 'lib', 'tasks', 'fix_*.rake'))
  Rails.autoloaders.main.ignore(File.join(plugin_root, 'scripts'))
end

# 在插件加载时立即加载所有必要的文件
# 按正确的顺序加载以避免依赖问题
require File.join(plugin_root, 'lib', 'webhook_notifier')
require File.join(plugin_root, 'lib', 'webhook_issue_hook')
require File.join(plugin_root, 'lib', 'webhook_task_reminder', 'holiday_calendar')
require File.join(plugin_root, 'lib', 'webhook_task_reminder', 'cache_lock')
require File.join(plugin_root, 'lib', 'webhook_task_reminder', 'database_lock')
require File.join(plugin_root, 'lib', 'webhook_task_reminder', 'runner')
require File.join(plugin_root, 'lib', 'webhook_task_reminder', 'scheduler')

Redmine::Plugin.register :redmine_webhook do
  name 'Redmine Webhook Plugin'
  author 'carolcoral'
  description 'Webhook notification plugin for Redmine with DingTalk support'
  version '1.0.4'
  url 'https://github.com/carolcoral/redmine_webhook'
  author_url 'https://github.com/carolcoral'

  project_module :webhook do
    permission :manage_webhook, {:webhook_settings => [:index, :update]}
  end

  menu :project_menu, :webhook, { :controller => 'webhook_settings', :action => 'index' },
       :caption => :label_webhook,
       :after => :settings,
       :param => :project_id
end

# 确保钩子被 Redmine 识别
Rails.configuration.to_prepare do
  # 使用 require_dependency 确保在开发环境下重新加载
  require_dependency 'webhook_issue_hook'
  
  # 注册钩子
  Redmine::Hook.add_listener(WebhookIssueHook)
  
  Rails.logger.info "[WebhookPlugin] Webhook plugin initialized"
  Rails.logger.info "[WebhookPlugin] WebhookIssueHook registered as listener: #{Redmine::Hook.listeners.include?(WebhookIssueHook)}"
end

# 插件加载后自动启动"任务提醒"定时器（每个进程只启动一次）
Rails.application.config.after_initialize do
  begin
    # 确保任务提醒字段存在
    ensure_task_reminder_fields!

    # 启动定时器
    WebhookTaskReminder::Scheduler.start!
    Rails.logger.info "[WebhookPlugin] Task reminder scheduler started successfully"
  rescue => e
    Rails.logger.error "[WebhookPlugin] Failed to initialize task reminder: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end


# 确保任务提醒相关字段存在的私有方法
def ensure_task_reminder_fields!
  return unless ActiveRecord::Base.connection.table_exists?(:webhook_configs)

  columns = ActiveRecord::Base.connection.columns(:webhook_configs).map(&:name)

  fields_config = {
    task_reminder_enabled: { type: :boolean, null: false, default: false },
    task_reminder_hour: { type: :integer, null: false, default: 9 },
    task_reminder_minute: { type: :integer, null: false, default: 0 },
    task_reminder_template: { type: :text },
    work_status_field_name: { type: :string, null: false, default: '工作状态' },
    work_status_on_duty_value: { type: :string, null: false, default: '在岗' }
  }

  fields_config.each do |field_name, config|
    next if columns.include?(field_name.to_s)

    begin
      ActiveRecord::Base.connection.add_column(
        :webhook_configs,
        field_name,
        config[:type],
        **config.except(:type)
      )
      Rails.logger.info "[WebhookPlugin] Added missing column: #{field_name}"
    rescue => e
      Rails.logger.warn "[WebhookPlugin] Failed to add column #{field_name}: #{e.message}"
    end
  end

  # 添加索引（如果不存在）
  index_name = 'index_webhook_configs_on_task_reminder_enabled'
  unless ActiveRecord::Base.connection.index_exists?(:webhook_configs, :task_reminder_enabled, name: index_name)
    begin
      ActiveRecord::Base.connection.add_index(:webhook_configs, :task_reminder_enabled, name: index_name)
      Rails.logger.info "[WebhookPlugin] Added index: #{index_name}"
    rescue => e
      Rails.logger.warn "[WebhookPlugin] Failed to add index #{index_name}: #{e.message}"
    end
  end
end