# frozen_string_literal: true

module AiAssistant
  # 工作报告生成器 -- 基于用户行为数据生成日报/周报/月报
  class ReportGenerator
    # ========== 常量 ==========
    REPORT_TYPES = %w[daily weekly monthly].freeze

    attr_reader :user, :report_type, :timezone, :provider_id

    def initialize(user, report_type:, timezone: nil, provider_id: nil)
      @user        = user
      @report_type = report_type.to_s
      @timezone    = timezone || Setting.user_format_time_zone(user) rescue 'UTC'
      @provider_id = provider_id

      raise ArgumentError, "Invalid report type: #{report_type}" unless REPORT_TYPES.include?(@report_type)
    end

    # 收集用户行为数据
    def collect_data
      range = time_range

      {
        user_name:      user.name,
        report_type:    report_type,
        period:         "#{range.begin.to_date} ~ #{range.end.to_date}",
        time_entries:   fetch_time_entries(range),
        issues_created: fetch_issues_created(range),
        issues_updated: fetch_issues_updated(range),
        issues_closed:  fetch_issues_closed(range),
        comments:       fetch_comments(range),
        wiki_updates:   fetch_wiki_updates(range),
        projects:       user_projects
      }
    end

    # 生成报告（调用 AI）
    def generate
      data = collect_data
      provider = resolve_provider
      client   = AiClient.new(provider)

      system_prompt = build_system_prompt
      user_prompt   = build_user_prompt(data)

      messages = [
        { role: 'system', content: system_prompt },
        { role: 'user',   content: user_prompt }
      ]

      result = client.chat(messages, temperature: 0.3, max_tokens: 8192)

      if result[:error]
        { error: result[:error] }
      else
        # 保存生成的报告
        record = AiMessage.create!(
          user:          user,
          ai_provider:   provider,
          conversation_id: "report_#{SecureRandom.uuid}",
          role:          'assistant',
          content:       result[:content],
          model:         result[:model],
          tokens_used:   result[:tokens_used],
          report_type:   report_type
        )

        {
          content:     result[:content],
          message_id:  record.id,
          tokens_used: result[:tokens_used]
        }
      end
    end

    private

    def time_range
      tz_offset = ActiveSupport::TimeZone.new(timezone)&.utc_offset || 0
      now = Time.current

      case report_type
      when 'daily'
        start_time = now.beginning_of_day - tz_offset
        end_time   = now.end_of_day - tz_offset
      when 'weekly'
        start_time = now.beginning_of_week - tz_offset
        end_time   = now.end_of_week - tz_offset
      when 'monthly'
        start_time = now.beginning_of_month - tz_offset
        end_time   = now.end_of_month - tz_offset
      end

      start_time..end_time
    end

    def fetch_time_entries(range)
      TimeEntry.where(user_id: user.id)
               .where(spent_on: range.begin.to_date..range.end.to_date)
               .includes(:project, :issue, :activity)
               .order(spent_on: :desc)
               .map do |entry|
        {
          date:     entry.spent_on.to_s,
          hours:    entry.hours,
          project:  entry.project&.name,
          issue:    entry.issue&.subject,
          activity: entry.activity&.name,
          comments: entry.comments
        }
      end
    end

    def fetch_issues_created(range)
      Issue.where(author_id: user.id)
           .where(created_on: range)
           .includes(:project, :tracker, :status, :priority)
           .order(created_on: :desc)
           .map do |issue|
        {
          id:       issue.id,
          subject:  issue.subject,
          project:  issue.project&.name,
          tracker:  issue.tracker&.name,
          status:   issue.status&.name,
          priority: issue.priority&.name,
          created:  issue.created_on.to_s
        }
      end
    end

    def fetch_issues_updated(range)
      Journal.where(user_id: user.id)
             .where(created_on: range)
             .where(journalized_type: 'Issue')
             .includes(:issue)
             .order(created_on: :desc)
             .group_by(&:journalized_id)
             .transform_values { |journals| journals.map { |j| extract_journal_details(j) } }
    rescue StandardError
      {}
    end

    def fetch_issues_closed(range)
      Issue.where(assigned_to_id: user.id)
           .where(status_id: IssueStatus.where(is_closed: true).pluck(:id))
           .where(closed_on: range)
           .includes(:project, :tracker, :priority)
           .order(closed_on: :desc)
           .map do |issue|
        {
          id:       issue.id,
          subject:  issue.subject,
          project:  issue.project&.name,
          tracker:  issue.tracker&.name,
          priority: issue.priority&.name,
          closed:   issue.closed_on.to_s
        }
      end
    end

    def fetch_comments(range)
      Journal.where(user_id: user.id)
             .where(created_on: range)
             .where.not(notes: [nil, ''])
             .includes(:journalized)
             .order(created_on: :desc)
             .map do |journal|
        {
          content: journal.notes,
          target:  journal_type_label(journal),
          created: journal.created_on.to_s
        }
      end
    end

    def fetch_wiki_updates(range)
      WikiContent::Version
        .joins('INNER JOIN wiki_contents ON wiki_contents.id = wiki_content_versions.wiki_content_id')
        .joins('INNER JOIN wiki_pages ON wiki_pages.id = wiki_contents.page_id')
        .joins('INNER JOIN wikis ON wikis.id = wiki_pages.wiki_id')
        .where(wiki_content_versions: { author_id: user.id })
        .where(wiki_content_versions: { updated_on: range })
        .select('wiki_content_versions.*, wiki_pages.title as page_title, wiki_pages.project_id')
        .order(updated_on: :desc)
        .map do |v|
        { page: v.page_title, updated: v.updated_on.to_s }
      end
    rescue StandardError
      []
    end

    def user_projects
      user.projects.active.pluck(:name)
    end

    def extract_journal_details(journal)
      {
        issue:     journal.issue&.subject,
        notes:     journal.notes,
        created:   journal.created_on.to_s,
        details:   journal.visible_details.map { |d| "#{d.prop_key}: #{d.old_value} → #{d.value}" }
      }
    end

    def journal_type_label(journal)
      case journal.journalized_type
      when 'Issue' then "问题 ##{journal.journalized_id}"
      when 'WikiPage' then 'Wiki 页面'
      when 'Document' then '文档'
      when 'News' then '新闻'
      else "#{journal.journalized_type} ##{journal.journalized_id}"
      end
    end

    def resolve_provider
      return AiProvider.enabled.ordered.first if provider_id.blank?

      AiProvider.enabled.find_by(id: provider_id) || AiProvider.enabled.ordered.first
    end

    def build_system_prompt
      GuardPrompt::GUARD_PREFIX + <<~PROMPT
        You are a professional work report generator for Redmine project management system.
        Generate a well-structured #{report_type} work report based on the provided data.

        Report format guidelines:
        - Use clear headings: "## 📊 #{report_type_label}工作报告"
        - Include sections: 工作总结, 时间分配, 问题跟进, 下周/下期计划
        - Use tables for numerical data when appropriate
        - Keep the tone professional and factual
        - Summarize key accomplishments and blockers
        - Total time entries hours
        - Highlight important issues
        - Output in Markdown format
        - Use the user's language (Chinese by default unless data indicates otherwise)
      PROMPT
    end

    def build_user_prompt(data)
      <<~PROMPT
        Please generate a #{report_type} work report for user: #{data[:user_name]}
        Report period: #{data[:period]}

        ## Raw Data

        ### Time Entries (#{data[:time_entries].length} records)
        #{format_time_entries(data[:time_entries])}

        ### Issues Created (#{data[:issues_created].length} records)
        #{format_issues(data[:issues_created])}

        ### Issues Closed (#{data[:issues_closed].length} records)
        #{format_issues(data[:issues_closed])}

        ### Comments Made (#{data[:comments].length} records)
        #{format_comments(data[:comments])}

        ### Projects Involved
        #{data[:projects].join(', ')}

        Generate the report now.
      PROMPT
    end

    def report_type_label
      case report_type
      when 'daily'   then '日报'
      when 'weekly'  then '周报'
      when 'monthly' then '月报'
      end
    end

    def format_time_entries(entries)
      return '(无)' if entries.empty?

      entries.map do |e|
        "- #{e[:date]} | #{e[:hours]}h | #{e[:project]} | #{e[:issue] || 'N/A'} | #{e[:activity]} #{e[:comments].present? ? "| #{e[:comments]}" : ''}"
      end.join("\n")
    end

    def format_issues(issues)
      return '(无)' if issues.empty?

      issues.map do |i|
        "- ##{i[:id]} #{i[:subject]} [#{i[:tracker]}] [#{i[:status]}] [#{i[:priority]}] (#{i[:project]})"
      end.join("\n")
    end

    def format_comments(comments)
      return '(无)' if comments.empty?

      comments.first(20).map do |c|
        "- #{c[:created]}: #{c[:content].truncate(200)} (#{c[:target]})"
      end.join("\n")
    end
  end
end
