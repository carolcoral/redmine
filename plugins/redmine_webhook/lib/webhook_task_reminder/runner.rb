require 'active_support/time'
require 'socket'

module WebhookTaskReminder
  class Runner
    DEFAULT_TEMPLATE = "【${project}】任务提醒（${date}）\n以下成员当前没有被指派的未关闭任务：\n${users}".freeze

    def initialize(
      logger: Rails.logger,
      cache: Rails.cache,
      holiday_calendar: HolidayCalendar.new,
      lock: nil,
      force_database_lock: ENV['WEBHOOK_FORCE_DB_LOCK'] == 'true',
      default_use_cache_lock: ENV['WEBHOOK_USE_CACHE_LOCK'] == 'true'
    )
      @logger = logger
      @cache = cache
      @holiday_calendar = holiday_calendar

      # 锁后端选择逻辑：
      # 1. 如果明确指定强制使用数据库锁，则使用数据库锁
      # 2. 如果明确指定使用缓存锁，则尝试使用缓存锁
      # 3. 默认情况下，使用数据库锁（适用于多容器部署）

      begin
        if force_database_lock
          @logger.debug "[WebhookTaskReminder] Using database lock (WEBHOOK_FORCE_DB_LOCK=true)"
          @lock = DatabaseLock.new
        elsif default_use_cache_lock
          @logger.debug "[WebhookTaskReminder] Using cache lock (WEBHOOK_USE_CACHE_LOCK=true)"
          @lock = lock || CacheLock.new
        else
          # 默认使用数据库锁
          @logger.debug "[WebhookTaskReminder] Using database lock"
          @lock = lock || DatabaseLock.new
        end

        @logger.debug "[WebhookTaskReminder] Lock backend: #{@lock.class.name}"
      rescue => e
        # 如果创建数据库锁失败，降级到缓存锁
        @logger.warn "[WebhookTaskReminder] Failed to create database lock: #{e.message}, falling back to cache lock"
        @lock = CacheLock.new
        @logger.debug "[WebhookTaskReminder] Lock backend: #{@lock.class.name} (fallback)"
      end
    end

    def tick(now: nil)
      time_zone = Setting.respond_to?(:time_zone) ? Setting.time_zone : nil
      now = now || (time_zone.present? ? Time.use_zone(time_zone) { Time.zone.now } : Time.now)
      date = now.to_date

      return unless @holiday_calendar.workday?(date)

      # 获取启用了任务提醒的配置
      configs = if WebhookConfig.column_names.include?('task_reminder_enabled')
        WebhookConfig.where(task_reminder_enabled: true)
      else
        # 如果数据库字段不存在，返回空结果
        WebhookConfig.none
      end

      configs.includes(:project).find_each do |config|
          next unless config.enabled?
          next unless config.project&.module_enabled?(:webhook)

          # 检查是否被子项目禁用规则排除
          next if excluded_by_parent_project?(config)

          if due_now?(config, now)
            run_for_project(config, now)
          end
        end
    rescue StandardError => e
      @logger.error "[WebhookTaskReminder] tick failed: #{e.class}:#{e.message}"
      @logger.error e.backtrace.first(10).join("\n")
    end

    # 清理过期的锁（每天执行一次）
    def self.cleanup_expired_locks
      DatabaseLock.cleanup_expired_locks
    end

    private

    # 自动选择锁后端
    def select_lock_backend
      cache_lock = CacheLock.new

      # 测试缓存锁是否支持分布式锁
      probe_key = "redmine_webhook:lock_probe:#{SecureRandom.hex(8)}"
      supports_distributed = @cache.write(probe_key, '1', expires_in: 1.second, unless_exist: true)
      @cache.delete(probe_key) rescue nil

      if supports_distributed
        @logger.debug "[WebhookTaskReminder] Using cache lock (distributed)"
        return cache_lock
      else
        @logger.warn "[WebhookTaskReminder] Cache doesn't support distributed lock, using database lock"
        return DatabaseLock.new
      end
    rescue StandardError => e
      @logger.warn "[WebhookTaskReminder] Failed to detect lock support, using database lock: #{e.message}"
      DatabaseLock.new
    end

    def due_now?(config, now)
      now.hour == config.task_reminder_hour.to_i && now.min == config.task_reminder_minute.to_i
    end

    def run_for_project(config, now)
      project = config.project
      key = sent_lock_key(project.id, now)

      token = @lock.acquire(key, ttl: 26.hours)
      return unless token

      # 获取所有相关项目：当前项目、所有父项目、所有子项目
      project_ids = get_related_project_ids(project)

      on_duty_users = fetch_on_duty_project_users(project, config)
      return if on_duty_users.empty?

      user_ids = on_duty_users.map(&:id)
      open_assigned_counts = Issue
        .joins(:status)
        .where(project_id: project_ids, assigned_to_id: user_ids)
        .where(issue_statuses: { is_closed: false })
        .group(:assigned_to_id)
        .count

      no_task_users = on_duty_users.select { |u| open_assigned_counts[u.id].to_i <= 0 }
      return if no_task_users.empty?

      @logger.info "[WebhookTaskReminder] Sending reminder for project #{project.id}: #{no_task_users.count} users - #{no_task_users.map(&:name).join(', ')}"

      message = build_message(config, project, now, no_task_users)
      WebhookNotifier.send_custom_message(config, message)

      @logger.info "[WebhookTaskReminder] Task reminder sent successfully for project #{project.id}"
    rescue StandardError => e
      @logger.error "[WebhookTaskReminder] run_for_project failed: project_id=#{project&.id} err=#{e.class}:#{e.message}"
    end

    def get_related_project_ids(project)
      ids = [project.id]

      # 获取所有父项目
      parent = project.parent
      while parent
        ids << parent.id
        parent = parent.parent
      end

      # 获取所有子项目（递归）
      ids += get_all_sub_project_ids(project)

      ids.uniq
    end

    def get_all_sub_project_ids(project)
      ids = []
      children = Project.where(parent_id: project.id)
      children.each do |child|
        ids << child.id
        ids += get_all_sub_project_ids(child)
      end
      ids
    end

    def get_root_project(project)
      return project unless project.parent
      parent = project.parent
      while parent
        return parent unless parent.parent
        parent = parent.parent
      end
      project
    end

    def sent_lock_key(project_id, now)
      date_str = now.to_date.strftime('%Y-%m-%d')
      hm = format('%02d%02d', now.hour, now.min)
      "redmine_webhook:task_reminder:sent:project:#{project_id}:#{date_str}:#{hm}"
    end

    def fetch_on_duty_project_users(project, config)
      # 获取所有相关项目：当前项目、所有父项目、所有子项目
      project_ids = get_related_project_ids(project)

      # 获取需要提醒的角色
      reminder_roles = config.task_reminder_roles
      # 如果角色列表为空或无效，默认提醒所有角色的用户
      if reminder_roles.blank? || !reminder_roles.is_a?(Array)
        # 只包含非内置角色（排除匿名用户、非成员用户）
        reminder_roles = Role.where(builtin: false).pluck(:id)
      end

      users = User
        .joins(memberships: :member_roles)
        .where(members: { project_id: project_ids })
        .where(member_roles: { role_id: reminder_roles })
        .where(status: User::STATUS_ACTIVE)
        .distinct

      field_name = config.work_status_field_name.to_s.strip
      on_duty_value = config.work_status_on_duty_value.to_s.strip

      # 如果没有配置工作状态字段，默认所有用户都在岗
      return users.to_a if field_name.blank? || on_duty_value.blank?

      status_field = CustomField.find_by(type: 'UserCustomField', name: field_name)
      # 如果找不到工作状态字段，默认所有用户都在岗
      return users.to_a unless status_field

      values = CustomValue
        .where(customized_type: 'Principal', custom_field_id: status_field.id, customized_id: users.select(:id))
        .pluck(:customized_id, :value)
        .to_h

      # 筛选在岗用户：
      # 1. 工作状态值等于设置的在岗值
      # 2. 或者工作状态字段不存在/为空（默认认为在岗）
      users.to_a.select do |u|
        user_status = values[u.id].to_s.strip

        # 如果工作状态为空，默认认为在岗
        user_status.blank? || user_status == on_duty_value
      end
    rescue StandardError => e
      @logger.error "[WebhookTaskReminder] fetch_on_duty_project_users failed: project_id=#{project.id} err=#{e.class}:#{e.message}"
      []
    end

    def build_message(config, project, now, users)
      template = config.task_reminder_template.to_s
      template = DEFAULT_TEMPLATE if template.blank?

      date_str = now.strftime('%Y-%m-%d')
      users_text = users.map { |u| "- #{u.name}" }.join("\n")

      # 使用根项目名称
      root_project = get_root_project(project)
      project_name = root_project ? root_project.name.to_s : project.name.to_s

      text = template.dup
      text.gsub!('${project}', project_name)
      text.gsub!('${date}', date_str)
      text.gsub!('${users}', users_text)

      # 获取用户手机号
      phones_by_user = lookup_phones(users)

      # 区分有手机号和没有手机号的用户
      users_with_phone = users.select { |u| phones_by_user[u.id].present? }
      users_without_phone = users.select { |u| phones_by_user[u.id].blank? }

      at_info = {
        isAtAll: false
      }

      # 检测消息格式（基于原始模板）
      is_markdown = template.match?(/[#*`_\[\]]/) || template.match?(/<\/?(div|p|strong|b|i|u|a|img|table|ul|ol|li|h\d|br|hr|pre|code|span)[^>]*>/i)

      if is_markdown
        # Markdown格式：将@信息直接嵌入到消息文本中
        # 先添加有手机号的用户（@手机号，效果最佳）
        users_with_phone.each do |u|
          phone = phones_by_user[u.id]
          text += " @#{phone}"
        end

        # 再添加没有手机号的用户（@昵称）
        users_without_phone.each do |u|
          text += " @#{u.name}"
        end

        # Markdown的at参数仍然需要手机号（用于强提醒）
        # 注意：如果有多个用户使用相同手机号，atMobiles会自动去重
        # 但消息文本中的@手机号仍然会@到所有人
        at_info[:atMobiles] = users_with_phone.map { |u| phones_by_user[u.id] }.uniq
        at_info[:atDingtalkIds] = []
        at_info[:atUserIds] = []
      else
        # 纯文本格式：使用at参数实现@提醒
        # 有手机号的用户使用atMobiles
        # 注意：如果有多个用户使用相同手机号，atMobiles会自动去重
        # 因此需要在消息文本中为每个用户都添加@手机号或@昵称
        at_info[:atMobiles] = users_with_phone.map { |u| phones_by_user[u.id] }.uniq
        at_info[:atDingtalkIds] = []
        at_info[:atUserIds] = []

        # 在消息文本中添加@信息，确保所有用户都被@到
        # 先添加有手机号的用户
        users_with_phone.each do |u|
          text += " @#{phones_by_user[u.id]}"
        end

        # 再添加没有手机号的用户
        users_without_phone.each do |u|
          text += " @#{u.name}"
        end
      end

      # 为了保证 @ 生效，提醒消息默认走 text（DingTalk 的 markdown @ 行为不稳定）
      {
        msgtype: 'text',
        text: { content: text },
        at: at_info
      }
    end

    def lookup_phones(users)
      phone_field = CustomField.find_by(type: 'UserCustomField', name: '手机号')
      return {} unless phone_field

      values = CustomValue
        .where(customized_type: 'Principal', custom_field_id: phone_field.id, customized_id: users.map(&:id))
        .pluck(:customized_id, :value)
        .to_h

      # 返回 user_id -> phone 的映射，没有手机号的用户映射为 nil
      user_phones = {}
      users.each do |u|
        user_phones[u.id] = if values[u.id].present?
                              values[u.id].to_s.strip
                            else
                              nil
                            end
      end

      user_phones
    rescue StandardError => e
      @logger.error "[WebhookTaskReminder] lookup_phones failed: #{e.message}"
      {}
    end

    # 检查是否被子项目的禁用规则排除
    def excluded_by_parent_project?(config)
      project = config.project
      return false unless project.parent

      # 检查所有父项目
      parent = project.parent
      while parent
        parent_config = WebhookConfig.find_by(project_id: parent.id)
        if parent_config && parent_config.task_reminder_disable_sub_projects
          @logger.debug "[WebhookTaskReminder] Project #{project.id} excluded by parent project #{parent.id}"
          return true
        end
        parent = parent.parent
      end

      false
    rescue StandardError => e
      @logger.error "[WebhookTaskReminder] excluded_by_parent_project? failed: #{e.message}"
      false
    end
  end
end

