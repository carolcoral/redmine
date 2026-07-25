class WebhookNotificationJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, webhook_config_id)
    issue = Issue.find_by(id: issue_id)
    webhook_config = WebhookConfig.find_by(id: webhook_config_id)
    
    return unless issue && webhook_config && webhook_config.enabled?
    
    # Check if template exists for current status
    template = webhook_config.status_template(issue.status_id)
    return unless template.present?
    
    WebhookNotifier.notify(issue, webhook_config)
  rescue StandardError => e
    Rails.logger.error "[WebhookJob] Failed to process notification: #{e.message}\n#{e.backtrace.join("\n")}"
  end
end