class AddTaskReminderToWebhookConfigs < ActiveRecord::Migration[7.2]
  def change
    # 检查表是否存在
    return unless table_exists?(:webhook_configs)

    # 获取当前表的列信息
    columns = connection.columns(:webhook_configs).map(&:name)

    # 字段定义配置
    task_reminder_fields = [
      { name: :task_reminder_enabled, type: :boolean, null: false, default: false },
      { name: :task_reminder_hour, type: :integer, null: false, default: 9 },
      { name: :task_reminder_minute, type: :integer, null: false, default: 0 },
      { name: :task_reminder_template, type: :text },
      { name: :work_status_field_name, type: :string, null: false, default: '工作状态' },
      { name: :work_status_on_duty_value, type: :string, null: false, default: '在岗' }
    ]

    # 只添加不存在的字段
    task_reminder_fields.each do |field_config|
      field_name = field_config[:name]
      unless columns.include?(field_name.to_s)
        add_column(:webhook_configs, field_name, field_config[:type], **field_config.except(:name, :type))
        Rails.logger.info "[Migration] Added column #{field_name} to webhook_configs"
      end
    end

    # 添加索引（如果索引不存在）
    index_name = 'index_webhook_configs_on_task_reminder_enabled'
    unless index_exists?(:webhook_configs, :task_reminder_enabled, name: index_name)
      add_index :webhook_configs, :task_reminder_enabled, name: index_name
      Rails.logger.info "[Migration] Added index #{index_name}"
    end
  end
end


