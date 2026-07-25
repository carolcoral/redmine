class AddTaskReminderRolesToWebhookConfigs < ActiveRecord::Migration[7.2]
  def change
    # 检查表是否存在
    return unless table_exists?(:webhook_configs)

    # 获取当前表的列信息
    columns = connection.columns(:webhook_configs).map(&:name)

    # 添加字段：任务提醒角色列表
    unless columns.include?('task_reminder_roles')
      add_column :webhook_configs, :task_reminder_roles, :text
      Rails.logger.info "[Migration] Added column task_reminder_roles to webhook_configs"
    end
  end
end
