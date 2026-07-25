namespace :webhook do
  desc '检查并确保任务提醒相关字段存在'
  task ensure_task_reminder_fields: :environment do
    puts '检查 webhook_configs 表的任务提醒字段...'

    # 检查表是否存在
    unless ActiveRecord::Base.connection.table_exists?(:webhook_configs)
      puts '  [跳过] webhook_configs 表不存在'
      next
    end

    columns = ActiveRecord::Base.connection.columns(:webhook_configs).map(&:name)

    # 需要添加的字段配置
    fields_config = {
      task_reminder_enabled: { type: :boolean, null: false, default: false },
      task_reminder_hour: { type: :integer, null: false, default: 9 },
      task_reminder_minute: { type: :integer, null: false, default: 0 },
      task_reminder_template: { type: :text },
      work_status_field_name: { type: :string, null: false, default: '工作状态' },
      work_status_on_duty_value: { type: :string, null: false, default: '在岗' }
    }

    fields_added = 0
    fields_already_exist = 0

    fields_config.each do |field_name, config|
      if columns.include?(field_name.to_s)
        puts "  [✓] #{field_name} 已存在"
        fields_already_exist += 1
      else
        begin
          ActiveRecord::Base.connection.add_column(
            :webhook_configs,
            field_name,
            config[:type],
            **config.except(:type)
          )
          puts "  [+] #{field_name} 已添加"
          fields_added += 1
        rescue => e
          puts "  [!] #{field_name} 添加失败: #{e.message}"
        end
      end
    end

    # 检查并添加索引
    index_name = 'index_webhook_configs_on_task_reminder_enabled'
    unless ActiveRecord::Base.connection.index_exists?(:webhook_configs, :task_reminder_enabled, name: index_name)
      begin
        ActiveRecord::Base.connection.add_index(:webhook_configs, :task_reminder_enabled, name: index_name)
        puts "  [+] 索引 #{index_name} 已添加"
        fields_added += 1
      rescue => e
        puts "  [!] 索引添加失败: #{e.message}"
      end
    else
      puts "  [✓] 索引 #{index_name} 已存在"
      fields_already_exist += 1
    end

    puts "\n总结:"
    puts "  已存在: #{fields_already_exist}"
    puts "  新添加: #{fields_added}"

    if fields_added > 0
      puts "\n提示: 请重启 Rails 应用使更改生效"
    end
  end

  desc '显示 webhook_configs 表的当前字段'
  task show_columns: :environment do
    unless ActiveRecord::Base.connection.table_exists?(:webhook_configs)
      puts 'webhook_configs 表不存在'
      exit
    end

    puts 'webhook_configs 表字段列表:'
    puts '=' * 60

    columns = ActiveRecord::Base.connection.columns(:webhook_configs)
    columns.each do |col|
      nullable = col.null ? 'NULL' : 'NOT NULL'
      default = col.default.nil? ? '' : "DEFAULT #{col.default.inspect}"
      puts "  #{col.name.ljust(30)} #{col.type.to_s.ljust(10)} #{nullable.ljust(10)} #{default}"
    end
  end
end
