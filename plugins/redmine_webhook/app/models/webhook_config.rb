class WebhookConfig < ActiveRecord::Base
  belongs_to :project

  validates_presence_of :project_id, :webhook_url
  validates :webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  # 使用 YAML 序列化，兼容 Rails 7.2
  serialize :status_templates, coder: YAML, type: Hash
  serialize :enabled_statuses, coder: YAML, type: Array
  serialize :task_reminder_roles, coder: YAML, type: Array

  # 定义任务提醒相关字段的虚拟属性（兼容旧数据）
  TASK_REMINDER_FIELDS = %i[
    task_reminder_enabled
    task_reminder_hour
    task_reminder_minute
    task_reminder_template
    work_status_field_name
    work_status_on_duty_value
    task_reminder_disable_sub_projects
    task_reminder_roles
  ].freeze

  TASK_REMINDER_DEFAULTS = {
    task_reminder_enabled: false,
    task_reminder_hour: 9,
    task_reminder_minute: 0,
    task_reminder_template: '',
    work_status_field_name: '工作状态',
    work_status_on_duty_value: '在岗',
    task_reminder_disable_sub_projects: false,
    task_reminder_roles: []
  }.freeze

  # 为每个任务提醒字段动态定义 getter 和 setter
  TASK_REMINDER_FIELDS.each do |field|
    define_method(field) do
      if has_attribute?(field)
        read_attribute(field)
      else
        TASK_REMINDER_DEFAULTS[field]
      end
    end

    define_method("#{field}=") do |value|
      if has_attribute?(field)
        write_attribute(field, value)
      else
        # 字段不存在时，不抛出错误，静默忽略
        Rails.logger.debug "[WebhookConfig] Field #{field} does not exist, skipping assignment"
      end
    end
  end

  # 初始化时确保不为 nil
  after_initialize do
    self.status_templates ||= {}
    self.enabled_statuses ||= []
    self.task_reminder_roles ||= []
  end

  def self.for_project(project)
    # 检查哪些任务提醒字段存在于数据库中
    existing_columns = column_names
    task_reminder_fields_to_exclude = TASK_REMINDER_FIELDS.map(&:to_s).reject { |field| existing_columns.include?(field) }

    # 只排除不存在的字段
    if task_reminder_fields_to_exclude.any?
      config = select(column_names - task_reminder_fields_to_exclude).where(project_id: project.id).first_or_initialize
    else
      # 所有字段都存在，直接查询
      config = where(project_id: project.id).first_or_initialize
    end

    # 确保 enabled_statuses 是数组
    if config.enabled_statuses.is_a?(String)
      # 如果是字符串，尝试解析（可能序列化有问题）
      begin
        parsed = YAML.load(config.enabled_statuses)
        config.enabled_statuses = parsed.is_a?(Array) ? parsed : []
      rescue
        config.enabled_statuses = []
      end
    elsif !config.enabled_statuses.is_a?(Array)
      config.enabled_statuses = []
    end

    # 确保 task_reminder_roles 是数组
    if config.task_reminder_roles.is_a?(String)
      begin
        parsed = YAML.load(config.task_reminder_roles)
        config.task_reminder_roles = parsed.is_a?(Array) ? parsed : []
      rescue
        config.task_reminder_roles = []
      end
    elsif !config.task_reminder_roles.is_a?(Array)
      config.task_reminder_roles = []
    end

    # 如果角色列表为空，默认包含所有非内置角色
    if config.task_reminder_roles.empty?
      config.task_reminder_roles = Role.where(builtin: false).pluck(:id)
    end

    config
  end

  def status_template(status_name)
    return nil unless status_templates.is_a?(Hash)
    status_templates[status_name.to_s]
  end

  # 检查某个状态是否启用通知
  def status_enabled?(status_name)
    # 确保 enabled_statuses 是数组
    return false unless enabled_statuses.is_a?(Array)
    return false if enabled_statuses.empty?
    enabled_statuses.include?(status_name.to_s)
  end

  def enabled?
    enabled && webhook_url.present?
  end
end