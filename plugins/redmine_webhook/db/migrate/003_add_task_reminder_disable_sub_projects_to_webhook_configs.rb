class AddTaskReminderDisableSubProjectsToWebhookConfigs < ActiveRecord::Migration[7.2]
  def change
    # 检查表是否存在
    return unless table_exists?(:webhook_configs)

    # 获取当前表的列信息
    columns = connection.columns(:webhook_configs).map(&:name)

    # 添加字段：是否禁用子项目任务提醒
    unless columns.include?('task_reminder_disable_sub_projects')
      add_column :webhook_configs, :task_reminder_disable_sub_projects, :boolean, null: false, default: false
      Rails.logger.info "[Migration] Added column task_reminder_disable_sub_projects to webhook_configs"
    end
  end
end
