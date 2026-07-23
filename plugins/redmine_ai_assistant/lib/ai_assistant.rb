# frozen_string_literal: true

module AiAssistant
  PLUGIN_NAME = :redmine_ai_assistant

  # 判断是否启用了悬浮 AI 助手
  def self.enabled?
    User.current&.logged? &&
      Setting.plugin_redmine_ai_assistant&.dig('enabled') == '1'
  end
end
