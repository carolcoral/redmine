# frozen_string_literal: true

module AiAssistant
  class ChatController < ApplicationController
    before_action :require_login

    accept_api_auth :send_message, :history

    def send_message
      message = params[:message].to_s.strip
      conversation_id = params[:conversation_id].presence || SecureRandom.uuid

      if message.blank?
        render json: { error: 'Message is required' }, status: :bad_request
        return
      end

      # 保存用户消息
      user_msg = AiMessage.create!(
        user:            User.current,
        conversation_id: conversation_id,
        role:            'user',
        content:         message
      )

      # 加载历史消息
      history = load_conversation_history(conversation_id)

      # 注入 Guard Prompt（只读约束）
      system_content = build_system_content(message, history)

      # 构建消息数组
      messages = build_messages(system_content, history, message)

      # 调用 AI
      provider = resolve_provider
      client   = AiClient.new(provider)
      result   = client.chat(messages)

      if result[:error]
        render json: { error: result[:error] }, status: :service_unavailable
        return
      end

      # 保存 AI 回复
      assistant_msg = AiMessage.create!(
        user:            User.current,
        ai_provider:     provider,
        conversation_id: conversation_id,
        role:            'assistant',
        content:         result[:content],
        model:           result[:model],
        tokens_used:     result[:tokens_used]
      )

      render json: {
        conversation_id: conversation_id,
        message: {
          id:           assistant_msg.id,
          role:         'assistant',
          content:      result[:content],
          tokens_used:  result[:tokens_used]
        }
      }
    rescue StandardError => e
      Rails.logger.error "AI Chat Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: "内部错误: #{e.message}" }, status: :internal_server_error
    end

    def history
      conversation_id = params[:conversation_id]

      unless conversation_id
        render json: { error: 'conversation_id is required' }, status: :bad_request
        return
      end

      messages = AiMessage.by_conversation(conversation_id)
                          .where(user_id: User.current.id)

      render json: {
        conversation_id: conversation_id,
        messages: messages.map { |m|
          {
            id:          m.id,
            role:        m.role,
            content:     m.content,
            created_at:  m.created_at,
            tokens_used: m.tokens_used
          }
        }
      }
    end

    def clear
      conversation_id = params[:conversation_id]

      if conversation_id.present?
        AiMessage.where(conversation_id: conversation_id, user_id: User.current.id).delete_all
      end

      render json: { success: true }
    end

    private

    def resolve_provider
      provider_id = Setting.plugin_redmine_ai_assistant.try(:[], 'default_provider_id')
      if provider_id.present?
        AiProvider.enabled.find_by(id: provider_id)
      end || AiProvider.enabled.ordered.first
    end

    def load_conversation_history(conversation_id)
      max_messages = (Setting.plugin_redmine_ai_assistant.try(:[], 'max_history_messages') || 20).to_i

      AiMessage.by_conversation(conversation_id)
               .where(user_id: User.current.id)
               .order(created_at: :desc)
               .limit(max_messages)
               .reverse
    end

    def build_system_content(message, history)
      base = "You are an AI assistant integrated with Redmine.\n" \
             "Current user: #{User.current.name}\n" \
             "Current time: #{Time.current}"

      # 检测是否需要注入 Guard Prompt
      if GuardPrompt.guard_needed?(message) ||
         history.any? { |m| m.role == 'user' && GuardPrompt.guard_needed?(m.content) }
        base = GuardPrompt.inject(base, message)
      end

      base
    end

    def build_messages(system_content, history, current_message)
      messages = [{ role: 'system', content: system_content }]

      history.each do |msg|
        messages << { role: msg.role, content: msg.content }
      end

      # 如果 history 中还没有包含当前消息（因为我们在前面已经单独保存了）
      already_included = history.any? { |m| m.content == current_message && m.role == 'user' }
      unless already_included
        messages << { role: 'user', content: current_message }
      end

      messages
    end
  end
end
