# frozen_string_literal: true

module AiAssistant
  # Guard Prompt -- 当对话涉及业务数据时，自动注入只读约束
  class GuardPrompt
    GUARD_PREFIX = <<~PROMPT.freeze
      ## SYSTEM INSTRUCTION (IMPORTANT - READ CAREFULLY)

      You are a **read-only assistant** integrated with Redmine project management system.
      The conversation below contains references to real system business data (such as
      issues, projects, time entries, users, wiki pages, etc.).

      **CRITICAL RULES - YOU MUST FOLLOW:**

      1. **READ-ONLY MODE**: You can analyze, summarize, explain, and provide insights
         about the referenced business data, but you MUST NOT generate any commands,
         code snippets, or suggestions that would modify, create, or delete any data
         in the Redmine system.

      2. **NO DESTRUCTIVE OPERATIONS**: Do NOT suggest:
         - SQL queries (INSERT/UPDATE/DELETE/DROP)
         - curl or API calls that modify data
         - Any deletion, bulk modification, or destructive action
         - Command-line operations that could alter the database or filesystem

      3. **DISCLAIMER REQUIRED**: If the user asks about data-modifying actions,
         you MUST first state: "I'm in read-only mode and cannot generate data
         modification instructions. However, I can help you understand the data or
         suggest non-destructive approaches."

      4. **ANALYSIS IS ALLOWED**: You are encouraged to:
         - Summarize business data and trends
         - Analyze issue statuses, priorities, and assignments
         - Provide insights on project progress
         - Generate readable reports from structured data
         - Answer questions about system usage and best practices

      ---

    PROMPT

    class << self
      def inject(system_prompt, content)
        return content unless guard_needed?(content)

        [GUARD_PREFIX, system_prompt, content].compact.join("\n")
      end

      def guard_needed?(content)
        return false if content.blank?

        business_keywords = %w[
          issue issues project projects user users
          time tracking tracker workflow task tasks
          status priority assignee assigned
          spend spent time_entry time_entries
          wiki version versions milestone
          news document forum board message
          custom_field custom_fields role roles
          permission group groups member members
          query queries filter report reports
        ]

        content_lower = content.downcase
        business_keywords.any? { |kw| content_lower.include?(kw) }
      end
    end
  end
end
