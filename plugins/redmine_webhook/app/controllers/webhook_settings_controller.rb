class WebhookSettingsController < ApplicationController
  helper :webhook_settings
  before_action :find_project
  before_action :authorize

  # 将辅助方法暴露给视图
  helper_method :is_task_reminder_disabled_by_parent?

  require 'ostruct'

  def index
    @webhook_config = WebhookConfig.for_project(@project)
    @issue_statuses = IssueStatus.sorted.to_a
    @sub_projects = find_all_descendants(@project.id)
    # 只获取非内置角色（排除匿名用户、非成员用户）
    @all_roles = Role.where(builtin: false).sorted.to_a

    # 确保新字段有默认值（用于兼容旧数据）
    set_default_values_for_task_reminder(@webhook_config)

    # 如果任务提醒角色列表为空，默认选择所有角色
    if @webhook_config.task_reminder_roles.blank?
      @webhook_config.task_reminder_roles = @all_roles.pluck(:id)
    end

    # 为每个子项目标记是否已有webhook配置
    @sub_projects.each do |project|
      project.has_webhook_config = WebhookConfig.select(:id).where(project_id: project.id).exists?
      # 检查是否被子项目禁用规则排除
      project.task_reminder_disabled_by_parent = is_task_reminder_disabled_by_parent?(project)
    end
  end

  def update
    @webhook_config = WebhookConfig.for_project(@project)

    # 确保新字段有默认值（用于兼容旧数据）
    set_default_values_for_task_reminder(@webhook_config)

    # 确保 enabled_statuses 是数组
    if params[:webhook_config] && params[:webhook_config][:enabled_statuses].present?
      params[:webhook_config][:enabled_statuses] = params[:webhook_config][:enabled_statuses].reject(&:blank?).map(&:to_s)
    end

    # 确保 task_reminder_roles 是数组
    if params[:webhook_config] && params[:webhook_config][:task_reminder_roles].present?
      params[:webhook_config][:task_reminder_roles] = params[:webhook_config][:task_reminder_roles].reject(&:blank?).map(&:to_i)
    end

    success = false
    sync_stats = { created: 0, updated: 0 }
    
    ActiveRecord::Base.transaction do
      # 更新当前项目的配置
      Rails.logger.info "[Webhook] Updating webhook config: #{webhook_params.inspect}"
      if @webhook_config.update(webhook_params)
        Rails.logger.info "[Webhook] Webhook config updated successfully. Task reminder template: #{@webhook_config.task_reminder_template.inspect}"

        # 处理子项目同步
        if params[:sub_project_ids].present? && params[:sub_project_ids].any?(&:present?)
          sync_stats = sync_to_sub_projects(params[:sub_project_ids])
        end

        success = true
      else
        Rails.logger.error "[Webhook] Failed to update webhook config: #{@webhook_config.errors.full_messages.join(', ')}"
        raise ActiveRecord::Rollback
      end
    end
    
    if success
      # 构建成功消息
      notice_msg = l(:notice_successful_update)
      if sync_stats[:created] > 0 || sync_stats[:updated] > 0
        sync_msg = l(:notice_sub_projects_synced, count: sync_stats[:created] + sync_stats[:updated])
        notice_msg = "#{notice_msg} #{sync_msg}"
      end
      
      flash[:notice] = notice_msg
      redirect_to project_webhook_settings_path(@project)
    else
      @issue_statuses = IssueStatus.sorted.to_a
      @sub_projects = find_all_descendants(@project.id)
      render :index
    end
  rescue => e
    Rails.logger.error "[Webhook] Failed to save webhook config: #{e.message}"
    @issue_statuses = IssueStatus.sorted.to_a
      @sub_projects = find_all_descendants(@project.id)
      render :index
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end
  
  # 递归查询所有子项目（包括多层级）
  def find_all_descendants(project_id)
    descendants = []
    
    # 使用CTE递归查询（PostgreSQL和SQLite支持）
    # 对于MySQL需要使用不同的语法
    sql = <<-SQL
      WITH RECURSIVE project_tree AS (
        SELECT id, name, parent_id
        FROM projects
        WHERE parent_id = ?
        UNION ALL
        SELECT p.id, p.name, p.parent_id
        FROM projects p
        INNER JOIN project_tree pt ON p.parent_id = pt.id
      )
      SELECT id, name FROM project_tree
      ORDER BY name
    SQL
    
    begin
      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, project_id])
      )
      
      result.map do |row|
        OpenStruct.new(id: row['id'], name: row['name'], has_webhook_config: false)
      end
    rescue => e
      Rails.logger.error "Failed to fetch sub projects: #{e.message}"
      []
    end
  end

  def webhook_params
    # 获取基本参数，明确声明 enabled_statuses 是数组
    permitted = params.require(:webhook_config).permit(
      :webhook_url,
      :enabled,
      :secret_token,
      :task_reminder_enabled,
      :task_reminder_disable_sub_projects,
      :task_reminder_hour,
      :task_reminder_minute,
      :task_reminder_template,
      :work_status_field_name,
      :work_status_on_duty_value,
      enabled_statuses: [],
      task_reminder_roles: []
    )
    
    # 单独处理 status_templates，因为它包含动态键
    if params[:webhook_config][:status_templates]
      permitted[:status_templates] = params[:webhook_config][:status_templates].to_unsafe_h
    else
      permitted[:status_templates] = {}
    end
    
    # 确保 enabled_statuses 不为 nil（Rails 5+ 中 permit 后的数组参数可能为 nil）
    permitted[:enabled_statuses] ||= []
    # 过滤空值（来自隐藏字段的 ""）
    permitted[:enabled_statuses] = permitted[:enabled_statuses].reject { |v| v.blank? }.map(&:to_s)

    # 确保 task_reminder_roles 不为 nil
    permitted[:task_reminder_roles] ||= []
    # 如果为空数组，设置为所有非内置角色ID
    permitted[:task_reminder_roles] = permitted[:task_reminder_roles].reject(&:blank?).map(&:to_i)
    if permitted[:task_reminder_roles].empty?
      permitted[:task_reminder_roles] = Role.where(builtin: false).pluck(:id)
    end

    permitted
  end
  
  # 将当前配置同步到选中的子项目
  # 如果子项目已存在配置，则更新；否则创建新配置
  # 返回同步统计信息: { created: X, updated: Y }
  def sync_to_sub_projects(sub_project_ids)
    return { created: 0, updated: 0 } if sub_project_ids.blank?
    
    # 记录同步统计
    created_count = 0
    updated_count = 0
    
    sub_project_ids.each do |project_id|
      begin
        # 获取子项目对象
        sub_project = Project.find_by(id: project_id)
        next unless sub_project
        
        # 检查子项目是否启用了webhook模块
        has_webhook_module = sub_project.module_enabled?(:webhook)
        
        # 获取当前项目的配置数据（用于同步到子项目）
        config_attributes = {
          webhook_url: @webhook_config.webhook_url,
          secret_token: @webhook_config.secret_token,
          # 如果子项目没有启用webhook模块，则禁用webhook
          enabled: has_webhook_module ? @webhook_config.enabled : false,
          enabled_statuses: @webhook_config.enabled_statuses,
          status_templates: @webhook_config.status_templates,
          task_reminder_enabled: has_webhook_module && !@webhook_config.task_reminder_disable_sub_projects ? @webhook_config.task_reminder_enabled : false,
          task_reminder_disable_sub_projects: @webhook_config.task_reminder_disable_sub_projects,
          task_reminder_hour: @webhook_config.task_reminder_hour,
          task_reminder_minute: @webhook_config.task_reminder_minute,
          task_reminder_template: @webhook_config.task_reminder_template,
          work_status_field_name: @webhook_config.work_status_field_name,
          work_status_on_duty_value: @webhook_config.work_status_on_duty_value,
          task_reminder_roles: @webhook_config.task_reminder_roles,
          updated_at: Time.now
        }

        Rails.logger.debug "[Webhook] Syncing to sub-project #{project_id}: task_reminder_template=#{config_attributes[:task_reminder_template].inspect}"

        # 查找现有配置或初始化新配置
        # 检查哪些字段不存在，只排除不存在的字段
        existing_columns = WebhookConfig.column_names
        task_reminder_fields = %w[task_reminder_enabled task_reminder_hour task_reminder_minute task_reminder_template work_status_field_name work_status_on_duty_value]
        missing_fields = task_reminder_fields.reject { |field| existing_columns.include?(field) }

        Rails.logger.info "[Webhook] Sub-project #{project_id}: existing_columns=#{existing_columns.inspect}, missing_fields=#{missing_fields.inspect}"

        if missing_fields.any?
          Rails.logger.warn "[Webhook] Sub-project #{project_id}: Missing fields #{missing_fields.inspect}, will not sync these fields"
          sub_config = WebhookConfig.select(existing_columns - missing_fields).find_or_initialize_by(project_id: project_id)
        else
          sub_config = WebhookConfig.find_or_initialize_by(project_id: project_id)
        end

        was_new_record = sub_config.new_record?

        Rails.logger.debug "[Webhook] Sub-project #{project_id}: was_new_record=#{was_new_record}, current task_reminder_template=#{sub_config.task_reminder_template.inspect}"

        # 更新配置（这会同时处理新建和更新）
        if sub_config.update(config_attributes)
          Rails.logger.info "[Webhook] Sub-project #{project_id} sync success. Updated task_reminder_template to: #{sub_config.task_reminder_template.inspect}"
          if was_new_record
            created_count += 1
            Rails.logger.info "[Webhook] Created new webhook config for sub-project #{project_id} (webhook module enabled: #{has_webhook_module})"
          else
            updated_count += 1
            Rails.logger.info "[Webhook] Updated existing webhook config for sub-project #{project_id} (webhook module enabled: #{has_webhook_module})"
          end
        else
          Rails.logger.error "[Webhook] Failed to sync config to sub-project #{project_id}: #{sub_config.errors.full_messages.join(', ')}"
          raise ActiveRecord::Rollback, "Failed to sync config to sub-project #{project_id}"
        end
      rescue => e
        Rails.logger.error "[Webhook] Exception while syncing to sub-project #{project_id}: #{e.message}"
        raise ActiveRecord::Rollback, "Exception during sync: #{e.message}"
      end
    end
    
    Rails.logger.info "[Webhook] Sync completed: #{created_count} created, #{updated_count} updated"
    
    # 返回同步统计
    { created: created_count, updated: updated_count }
  end

  # 确保任务提醒相关字段有默认值（兼容旧数据）
  def set_default_values_for_task_reminder(config)
    task_reminder_fields = {
      task_reminder_enabled: false,
      task_reminder_hour: 9,
      task_reminder_minute: 0,
      task_reminder_template: '',
      work_status_field_name: '工作状态',
      work_status_on_duty_value: '在岗',
      task_reminder_disable_sub_projects: false,
      task_reminder_roles: []
    }

    task_reminder_fields.each do |field, default_value|
      if config.has_attribute?(field)
        current_value = config.send(field)
        Rails.logger.debug "[Webhook] Field #{field}: current_value=#{current_value.inspect}, has_attribute=#{config.has_attribute?(field)}"
        # 如果值为nil或blank，则设置默认值
        if current_value.nil?
          config.send("#{field}=", default_value)
          Rails.logger.debug "[Webhook] Set default value for #{field}: #{default_value.inspect}"
        end
      end
    end
  end

  # 检查项目的任务提醒是否被父项目禁用
  def is_task_reminder_disabled_by_parent?(project)
    return false unless project.parent

    parent = project.parent
    while parent
      parent_config = WebhookConfig.find_by(project_id: parent.id)
      if parent_config && parent_config.task_reminder_disable_sub_projects
        return true
      end
      parent = parent.parent
    end

    false
  end
end