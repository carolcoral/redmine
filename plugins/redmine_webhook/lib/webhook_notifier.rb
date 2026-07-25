require 'uri'
require 'net/http'
require 'json'
require 'openssl'
require 'base64'

class WebhookNotifier
  def self.notify(issue, webhook_config)
    new(webhook_config).send_notification(issue)
  end

  def self.send_custom_message(webhook_config, message)
    new(webhook_config).send_custom_message(message)
  end

  def initialize(webhook_config)
    @webhook_config = webhook_config
    @project = webhook_config.project
  end

  def send_notification(issue)
    unless @webhook_config.enabled?
      return false
    end
    
    status_name = issue.status.name
    template = @webhook_config.status_template(status_name)
    unless template.present?
      Rails.logger.warn "[Webhook] No template found for status '#{status_name}'"
      return false
    end

    message = build_message(issue, template)
    send_to_dingtalk(message)
  rescue StandardError => e
    Rails.logger.error "[Webhook] Failed to send notification: #{e.message}"
    false
  end

  def send_custom_message(message)
    unless @webhook_config.enabled?
      return false
    end
    send_to_dingtalk(message)
  rescue StandardError => e
    Rails.logger.error "[Webhook] Failed to send custom message: #{e.message}"
    false
  end

  private

  def build_message(issue, template)
    # Get current user from journal if available
    current_user = if issue.current_journal && issue.current_journal.user
                     issue.current_journal.user.name
                   else
                     issue.author.name
                   end

    # Get assignee (指派人)
    assigned_to = if issue.assigned_to
                    issue.assigned_to.name
                  else
                    '未指派'
                  end

    # 仅在模板中包含${assigned_to}变量时，才尝试@指派人
    should_at_assignee = template.include?('${assigned_to}') && issue.assigned_to && issue.assigned_to.name != '未指派'
    
    # 如果应该@指派人，提前获取手机号
    phone = nil
    if should_at_assignee
      phone = get_user_phone(issue.assigned_to.id)
    end

    # 准备占位符
    placeholders = {
      '${user}' => current_user,
      '${task}' => issue.subject,
      '${status}' => issue.status.name,
      '${project}' => issue.project.name,
      '${url}' => issue_url(issue),
      '${notes}' => issue.current_journal.try(:notes) || '',
      '${priority}' => issue.priority.try(:name) || '',
      '${tracker}' => issue.tracker.try(:name) || ''
    }
    
    # ${assigned_to}占位符特殊处理：根据是否有手机号决定是否显示
    if should_at_assignee
      if phone.present?
        # 有手机号：不显示${assigned_to}的值（因为后面会添加@手机号）
        placeholders['${assigned_to}'] = ''
      else
        # 没有手机号：正常显示指派人的名称
        placeholders['${assigned_to}'] = assigned_to
      end
    else
      # 模板中没有${assigned_to}变量，不需要处理
      placeholders['${assigned_to}'] = assigned_to if template.include?('${assigned_to}')
    end

    message_text = template.dup
    placeholders.each do |placeholder, value|
      message_text.gsub!(placeholder, value.to_s)
    end

    # 构建at信息
    at_info = {
      isAtAll: false  # 不@所有人
    }
    
    # 如果应该@指派人
    if should_at_assignee
      # 检查消息格式类型
      is_markdown = template.match?(/[#*`_\[\]]/) || template.match?(/<\/?(div|p|strong|b|i|u|a|img|table|ul|ol|li|h\d|br|hr|pre|code|span)[^>]*>/i)
      
      if is_markdown
        # Markdown格式：将@信息直接嵌入到消息文本中
        if phone.present?
          # 如果有手机号，在消息末尾添加@手机号（效果最佳）
          message_text += " @#{phone}"
          Rails.logger.info "[WebhookNotifier] Markdown消息嵌入手机号@: #{phone}"
        elsif !message_text.include?("@#{issue.assigned_to.name}")
          # 如果没有手机号，但至少显示@昵称
          message_text += " @#{issue.assigned_to.name}"
          Rails.logger.info "[WebhookNotifier] Markdown消息嵌入昵称@: #{issue.assigned_to.name}"
        end
        
        # Markdown消息的at参数仍然需要，但效果有限
        at_info[:atMobiles] = phone.present? ? [phone] : []
        at_info[:atDingtalkIds] = []
        at_info[:atUserIds] = []
      else
        # 纯文本格式：使用at参数实现@提醒，不在消息文本中添加@（避免重复）
        if phone.present?
          at_info[:atMobiles] = [phone]
          at_info[:atDingtalkIds] = []
          at_info[:atUserIds] = []
          Rails.logger.info "[WebhookNotifier] 纯文本格式使用手机号at参数: #{issue.assigned_to.name} (#{phone})"
        else
          at_info[:atMobiles] = []
          at_info[:atDingtalkIds] = []
          at_info[:atUserIds] = []
          Rails.logger.info "[WebhookNotifier] 纯文本格式未找到手机号，仅显示昵称: #{issue.assigned_to.name}"
        end
        
        # 纯文本格式不修改message_text，避免与模板中的${assigned_to}重复
        # at参数已经可以实现@提醒效果
      end
    end

    # 检测消息格式（基于原始模板，而不是替换后的消息）
    if template.match?(/[#*`_\[\]]/) || template.match?(/<\/?(div|p|strong|b|i|u|a|img|table|ul|ol|li|h\d|br|hr|pre|code|span)[^>]*>/i)
      # Use Markdown format
      {
        msgtype: 'markdown',
        markdown: {
          title: "#{issue.project.name} - #{issue.subject}",
          text: message_text
        },
        at: at_info
      }
    else
      # Use plain text format
      {
        msgtype: 'text',
        text: {
          content: message_text
        },
        at: at_info
      }
    end
  end

  def send_to_dingtalk(message)
    Rails.logger.info "[WebhookNotifier] Original webhook URL: #{@webhook_config.webhook_url}"
    Rails.logger.info "[WebhookNotifier] Secret token present: #{@webhook_config.secret_token.present?}"
    
    uri = URI.parse(@webhook_config.webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'

    payload = message.to_json
    
    # 保存原始URL用于日志
    final_uri = uri.dup
    
    # Add signature if secret token is configured
    if @webhook_config.secret_token.present?
      timestamp = (Time.now.to_f * 1000).to_i
      sign = generate_sign(timestamp, @webhook_config.secret_token)
      
      # 保留原有的 query 参数并添加签名参数
      params = URI.decode_www_form(uri.query || '').to_h
      params['timestamp'] = timestamp
      params['sign'] = sign
      final_uri.query = URI.encode_www_form(params)
      
      Rails.logger.info "[WebhookNotifier] Added signature to URL"
    end

    Rails.logger.info "[WebhookNotifier] Final webhook URL: #{final_uri}"
    Rails.logger.info "[WebhookNotifier] Has access_token: #{final_uri.query&.include?('access_token') ? 'yes' : 'no'}"
    Rails.logger.info "[WebhookNotifier] Request payload: #{payload}"

    request = Net::HTTP::Post.new(final_uri.request_uri)
    request.content_type = 'application/json'
    request.body = payload
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      if result['errcode'] == 0
        Rails.logger.info "[Webhook] Notification sent successfully to #{@project.name}"
        true
      else
        Rails.logger.error "[Webhook] DingTalk API error: #{result['errmsg']}"
        false
      end
    else
      Rails.logger.error "[Webhook] HTTP error: #{response.code}"
      false
    end
  end

  def generate_sign(timestamp, secret)
    string_to_sign = "#{timestamp}\n#{secret}"
    hash = OpenSSL::HMAC.digest('SHA256', secret, string_to_sign)
    Base64.encode64(hash).strip
  end

  def issue_url(issue)
    Setting.protocol + '://' + Setting.host_name + '/issues/' + issue.id.to_s
  end
  
  # 从Redmine自定义字段中获取用户手机号
  # 查询逻辑：
  # 1. 从custom_fields表中查找type='UserCustomField'且name='手机号'的字段ID
  # 2. 从custom_values表中根据user_id(customized_id)和custom_field_id查询value
  # 注意：customized_type应该是'Principal'（Redmine内部使用Principal而不是User）
  def get_user_phone(user_id)
    return nil unless user_id.present?
    
    begin
      # 查询手机号自定义字段的ID
      phone_field = CustomField.find_by(
        type: 'UserCustomField',
        name: '手机号'
      )
      
      return nil unless phone_field.present?
      
      # 查询该用户的手机号值
      # IMPORTANT: customized_type必须是'Principal'（Redmine内部机制）
      phone_value = CustomValue.find_by(
        customized_type: 'Principal',
        customized_id: user_id,
        custom_field_id: phone_field.id
      )
      
      if phone_value.present? && phone_value.value.present?
        phone = phone_value.value.to_s.strip
        Rails.logger.info "[WebhookNotifier] 获取到用户ID #{user_id} 的手机号: #{phone}"
        return phone
      else
        Rails.logger.info "[WebhookNotifier] 未找到用户ID #{user_id} 的手机号"
        return nil
      end
    rescue => e
      Rails.logger.error "[WebhookNotifier] 获取用户手机号失败: #{e.message}"
      return nil
    end
  end
end