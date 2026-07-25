class DetailsIssueHooks < Redmine::Hook::ViewListener
  def protect_against_forgery?
    false
  end

  def current_is_detail_page(context)
    # check if we see an issue but not creating a new one or on the specific edit page
    
    # Rails 7 compatibility: Use match? instead of rindex for better performance
    url = context[:request].original_url.to_s
    is_issues_controller = context[:controller].is_a?(IssuesController)
    is_issue_detail = url.match?(/\/issues\/\d+/) && !url.match?(/\/issues\/new/) && !url.match?(/\/issues\/\d+\/edit/)
    
    ret = context[:controller] && is_issues_controller && is_issue_detail
    ret
  end

  def view_layouts_base_html_head(context)
    unless current_is_detail_page(context)
      return
    end

    unless User.current.allowed_to?(:edit_issues, context[:project])
      return
    end

    begin
      # Rails 7 compatibility: Use plugin name as symbol
      css_tag = stylesheet_link_tag('issue_dynamic_edit.css', plugin: :redmine_issue_edit_online)
      css_tag
    rescue StandardError => e
      Rails.logger.error "[redmine_issue_edit_online] Failed to generate CSS tag: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      ""
    end
  end

  def view_layouts_base_body_bottom(context)
    unless current_is_detail_page(context)
      return
    end

    unless User.current.allowed_to?(:edit_issues, context[:project])
      return
    end
    
    # Inject plugin settings as safe window._CONF_* variables so client-side
    # scripts can read configured values without redeclaration issues.
    settings = Setting.plugin_redmine_issue_edit_online || {}
    force_https = settings['force_https'].to_s == '1' || settings['force_https'].to_s == 'true'
    display = settings['display_edit_icon'] || 'single'
    l_type_value = settings['listener_type_value'] || 'click'
    l_type_icon = settings['listener_type_icon'] || 'click'
    l_target = settings['listener_target'] || 'value'
    excluded_raw = settings['excluded_field_id'].to_s
    excluded_array = excluded_raw.split(',').map(&:strip).reject(&:empty?)
    check_conflict = settings['check_issue_update_conflict'].to_s == '1' || settings['check_issue_update_conflict'].to_s == 'true'

    script = "<script>\n"
    script << "window._CONF_FORCE_HTTPS = #{force_https ? 'true' : 'false'};\n"
    script << "window._CONF_DISPLAY_EDIT_ICON = #{display.inspect};\n"
    script << "window._CONF_LISTENER_TYPE_VALUE = #{l_type_value.inspect};\n"
    script << "window._CONF_LISTENER_TYPE_ICON = #{l_type_icon.inspect};\n"
    script << "window._CONF_LISTENER_TARGET = #{l_target.inspect};\n"
    script << "window._CONF_EXCLUDED_FIELD_ID = [#{excluded_array.map(&:inspect).join(', ')}];\n"
    script << "window._CONF_CHECK_ISSUE_UPDATE_CONFLICT = #{check_conflict ? 'true' : 'false'};\n"
    script << "</script>\n"

    begin
      js_tag = javascript_include_tag('issue_dynamic_edit.js', plugin: :redmine_issue_edit_online)
      result = script + js_tag
      result.html_safe
    rescue StandardError => e
      Rails.logger.error "[redmine_issue_edit_online] Failed to inject JavaScript: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      script.html_safe
    end
  end

  def view_issues_show_details_bottom(context)
    begin
      issue_id = context[:request].path_parameters[:id]
      project_id = issue_id ? Issue.find(issue_id).project_id : nil
    rescue
      issue_id = nil
      project_id = nil
    end

    content = "<script>\n"
    content << " const _ISSUE_ID = \"#{issue_id}\";\n" if issue_id
    content << " const _PROJECT_ID = \"#{project_id}\";\n" if project_id
    content << " const _TXT_CONFLICT_TITLE = \"" + l(:ide_txt_notice_conflict_title) + "\";\n"
    content << " const _TXT_CONFLICT_TXT = \"" + l(:ide_txt_notice_conflict_text) + "\";\n"
    content << " const _TXT_CONFLICT_LINK = \"" + l(:ide_txt_notice_conflict_link) + "\";\n"
    content << " const _COMMENTS_IN_REVERSE_ORDER = #{User.current.wants_comments_in_reverse_order? ? 'true' : 'false'};\n"
    content << "</script>\n"
    content << "<style>/* PRINT MEDIAQUERY */\n"
    content << "@media print {\n"
    content << "body.controller-issues.action-show div.issue.details .subject .refreshData,\n"
    content << "body.controller-issues.action-show div.issue.details .iconEdit,\n"
    content << "body.controller-issues.action-show .dynamicEditField {\n"
    content << "display : none !important;\n"
    content << "height: 0;\n"
    content << "width: 0;\n"
    content << "overflow: hidden;\n"
    content << "padding : 0;\n"
    content << "margin: 0;\n"
    content << "}\n"
    content << "}</style>\n"
    
    return content.html_safe
  end

end
