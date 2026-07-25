module RedmineCalendarHelper
  def calendar_issue_context_menu(issue)
    content_tag :div, class: 'calendar-issue-context-menu', style: 'display: none;', data: { issue_id: issue.id } do
      content = ''.html_safe
      
      if User.current.allowed_to?(:edit_issues, issue.project)
        content << content_tag(:div, class: 'context-menu-item', data: { action: 'edit_assigned_to' }) do
          l(:button_change_assigned_to)
        end
        
        content << content_tag(:div, class: 'context-menu-separator')
      end
      
      if User.current.allowed_to?(:delete_issues, issue.project)
        content << content_tag(:div, class: 'context-menu-item', data: { action: 'delete_issue' }) do
          l(:button_delete)
        end
      end
      
      content
    end
  end

  def assignee_select_options(project)
    principals = []
    if project
      principals = project.principals.sort_by(&:name)
    else
      principals = Principal.active.joins(:members).distinct.sort_by(&:name)
    end
    
    options = principals.map { |p| [p.name, p.id] }
    options.unshift([l(:label_none), ''])
    options
  end

  def calendar_issue_html(issue)
    css_classes = ['calendar-issue', "tracker-#{issue.tracker_id}"]
    css_classes << 'closed' if issue.closed?
    css_classes << 'assigned-to-me' if issue.assigned_to_id == User.current.id
    
    content_tag :div, class: css_classes.join(' '), 
                data: { 
                  issue_id: issue.id,
                  start_date: issue.start_date,
                  due_date: issue.due_date
                },
                draggable: true do
      content = ''.html_safe
      
      if issue.assigned_to
        content << avatar(issue.assigned_to, size: 16).to_s
        content << ' '.html_safe
      end
      
      content << content_tag(:span, issue.subject, class: 'issue-subject')
      content << calendar_issue_context_menu(issue)
      
      content
    end
  end

  def calendar_javascript_data(project = nil)
    data = {
      create_issue_url: redmine_calendar_create_issue_path,
      update_issue_date_url: redmine_calendar_update_issue_date_path(id: 'ISSUE_ID'),
      update_assigned_to_url: redmine_calendar_update_issue_assigned_to_path(id: 'ISSUE_ID'),
      update_created_on_url: redmine_calendar_update_issue_created_on_path(id: 'ISSUE_ID'),
      delete_issue_url: redmine_calendar_destroy_issue_path(id: 'ISSUE_ID'),
      project_id: project&.id,
      assignee_options: assignee_select_options(project),
      translations: {
        confirm_delete: l(:text_are_you_sure),
        change_assigned_to: l(:button_change_assigned_to),
        change_created_on: l(:button_change_created_on),
        new_issue: l(:label_issue_new),
        error_occurred: l(:error_unable_delete_issue)
      }
    }
    
    content_tag :div, '', id: 'redmine-calendar-data', data: data.to_json do
      ''
    end.html_safe
  end
end