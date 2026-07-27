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

    # 任务/问题查询关键词（中英文），匹配 >= 2 个才触发数据注入
    TASK_QUERY_KEYWORDS = %w[
      任务 我的任务 task tasks 指派 assign 我 待办 代办 todo
      问题 issue issues
      今天 今日 today 本周 本月 week month
      状态 status 优先级 priority 进度 progress
      报告 report reports 汇总 summary
    ].freeze

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
      # 基础系统提示
      base = "You are an AI assistant integrated with Redmine.\n" \
             "Current user: #{User.current.name}\n" \
             "Current time: #{Time.current}"

      # 注入管理员自定义系统提示词（优先级最高，放在最前面）
      custom_prompt = load_custom_system_prompt
      if custom_prompt.present?
        base = "#{custom_prompt.strip}\n\n#{base}"
      end

      # 检测是否需要注入 Guard Prompt（需同时检查 guard_prompt_enabled 开关）
      guard_enabled = Setting.plugin_redmine_ai_assistant.try(:[], 'guard_prompt_enabled')
      if guard_enabled != '0' &&
         (GuardPrompt.guard_needed?(message) ||
          history.any? { |m| m.role == 'user' && GuardPrompt.guard_needed?(m.content) })
        base = GuardPrompt.inject(base, message)
      end

      # 检测任务/报告类查询，注入真实 Redmine 数据
      if task_query?(message)
        task_context = build_task_context
        base = "#{base}\n\n#{task_context}"
      end

      base
    end

    # 加载管理员自定义系统提示词
    def load_custom_system_prompt
      Setting.plugin_redmine_ai_assistant.try(:[], 'system_prompt').presence
    end

    # 判断是否为任务/报告类查询
    def task_query?(message)
      return false if message.blank?

      lower = message.downcase
      matched = TASK_QUERY_KEYWORDS.count { |kw| lower.include?(kw) }
      matched >= 2
    end

    # 构建当前用户的任务上下文数据
    def build_task_context
      user = User.current

      # 查询指派给当前用户的未关闭任务
      open_issues = Issue.where(assigned_to_id: user.id)
                        .where(status_id: IssueStatus.where(is_closed: false).pluck(:id))
                        .includes(:project, :tracker, :status, :priority)
                        .order(due_date: :asc, created_on: :desc)
                        .limit(50)

      # 查询指派给当前用户今天更新的任务
      today_updated = Issue.where(assigned_to_id: user.id)
                          .where.not(status_id: IssueStatus.where(is_closed: false).pluck(:id))
                          .where(updated_on: Time.current.beginning_of_day..Time.current.end_of_day)
                          .includes(:project, :tracker, :status, :priority)
                          .order(updated_on: :desc)
                          .limit(10)

      lines = []

      lines << "## REAL REDMINE DATA - Assigned Issues/Tasks for #{user.name}\n"

      if open_issues.empty?
        lines << "**No open issues/tasks assigned to #{user.name}.**"
      else
        lines << "### Open Issues Assigned to You (#{open_issues.count} total):"
        open_issues.each do |i|
          due = i.due_date ? "Due: #{i.due_date}" : "No due date"
          lines << "  - ##{i.id} [#{i.tracker&.name}] [#{i.status&.name}] [#{i.priority&.name}] #{i.subject} (Project: #{i.project&.name}, #{due})"
        end
      end

      unless today_updated.empty?
        lines << ""
        lines << "### Recently Resolved/Updated Today (assigned to you, #{today_updated.count} total):"
        today_updated.each do |i|
          lines << "  - ##{i.id} [#{i.status&.name}] #{i.subject} (Project: #{i.project&.name})"
        end
      end

      context = lines.join("\n")

      "#{context}\n\n**CRITICAL RULE: Only reference the tasks listed above. If the list shows no tasks, tell the user they currently have no assigned tasks. NEVER invent, guess, or fabricate tasks that are not explicitly listed above.**"
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
