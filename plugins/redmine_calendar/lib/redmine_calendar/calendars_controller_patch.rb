module RedmineCalendar
  module CalendarsControllerPatch
    def self.included(base)
      base.class_eval do
        helper :redmine_calendar
        helper_method :calendar_issues_json
      end
    end

    def calendar_issues_json(start_date, end_date)
      @calendar_issues = []
      if @project
        @calendar_issues = Issue.visible.where(project_id: @project.id)
                           .where("#{Issue.table_name}.start_date BETWEEN ? AND ? OR 
                                  #{Issue.table_name}.due_date BETWEEN ? AND ? OR 
                                  (#{Issue.table_name}.start_date <= ? AND #{Issue.table_name}.due_date >= ?)",
                                  start_date, end_date, start_date, end_date, start_date, end_date)
                           .includes(:assigned_to, :tracker, :status, :priority, :project)
                           .to_a
      else
        @calendar_issues = Issue.visible.where("#{Issue.table_name}.start_date BETWEEN ? AND ? OR 
                                  #{Issue.table_name}.due_date BETWEEN ? AND ? OR 
                                  (#{Issue.table_name}.start_date <= ? AND #{Issue.table_name}.due_date >= ?)",
                                  start_date, end_date, start_date, end_date, start_date, end_date)
                           .includes(:assigned_to, :tracker, :status, :priority, :project)
                           .to_a
      end

      issues_json = @calendar_issues.map do |issue|
        {
          id: issue.id,
          subject: issue.subject,
          start_date: issue.start_date,
          due_date: issue.due_date,
          tracker_name: issue.tracker.name,
          status_name: issue.status.name,
          assigned_to_id: issue.assigned_to_id,
          assigned_to_name: issue.assigned_to.try(:name),
          project_id: issue.project_id,
          project_name: issue.project.name,
          priority_id: issue.priority_id,
          is_closed: issue.closed?
        }
      end

      issues_json
    end
  end
end