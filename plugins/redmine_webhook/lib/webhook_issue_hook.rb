class WebhookIssueHook < Redmine::Hook::Listener
  # 当新问题创建后触发
  def controller_issues_new_after_save(context = {})
    issue = context[:issue]
    return unless issue && issue.project
    
    webhook_config = WebhookConfig.for_project(issue.project)
    return unless webhook_config&.enabled?
    return unless webhook_config.status_enabled?(issue.status.name)
    
    template = webhook_config.status_template(issue.status.name)
    return unless template.present?
    
    WebhookNotifier.notify(issue, webhook_config)
  rescue StandardError => e
    Rails.logger.error "[Webhook] Failed to send notification for new issue ##{issue.id}: #{e.message}"
  end
  
  # 当问题编辑保存后触发
  def controller_issues_edit_after_save(context = {})
    issue = context[:issue]
    journal = context[:journal]
    
    return unless issue && journal
    return unless issue.project
    
    status_change = journal.details.detect { |detail| detail.prop_key == 'status_id' }
    return unless status_change
    
    webhook_config = WebhookConfig.for_project(issue.project)
    return unless webhook_config&.enabled?
    return unless webhook_config.enabled_statuses.is_a?(Array) && webhook_config.enabled_statuses.any?
    
    new_status = IssueStatus.find_by(id: status_change.value)
    return unless new_status
    return unless webhook_config.status_enabled?(new_status.name)
    
    template = webhook_config.status_template(new_status.name)
    return unless template.present?
    
    WebhookNotifier.notify(issue, webhook_config)
  rescue StandardError => e
    Rails.logger.error "[Webhook] Failed to send notification for issue ##{issue.id}: #{e.message}"
  end
end