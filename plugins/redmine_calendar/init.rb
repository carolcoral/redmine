require 'redmine'

# Redmine Calendar Enhancement Plugin
# Minimal version to ensure basic functionality

Redmine::Plugin.register :redmine_calendar do
  name 'Redmine Calendar Enhancement'
  author 'Plugin Author'
  description 'Enhances Redmine calendar with drag-and-drop, double-click to create issues, and context menu features'
  version '1.0.4'
  url 'https://github.com/yourusername/redmine_calendar'
  author_url 'https://github.com/yourusername'

  requires_redmine version_or_higher: '6.1.0'

  settings default: {
    'show_issue_menu' => true,
    'enable_drag_drop' => true,
    'enable_double_click' => true
  }, partial: 'settings/redmine_calendar_settings'

  permission :edit_calendar_issues, { redmine_calendar: [:create_issue, :update_issue_date, :update_issue_assigned_to, :update_issue_created_on, :destroy_issue] }, require: :member
end

# Define settings helper
def RedmineCalendar.settings
  Setting.plugin_redmine_calendar
end

# Load hooks after initialization to avoid Zeitwerk issues
Rails.configuration.after_initialize do
  begin
    plugin_dir = Redmine::Plugin.find(:redmine_calendar).directory
    
    # Load hooks
    hooks_path = File.join(plugin_dir, 'lib', 'redmine_calendar', 'hooks.rb')
    if File.exist?(hooks_path)
      require hooks_path
      Rails.logger.info "[RedmineCalendar] Hooks loaded successfully"
    else
      Rails.logger.error "[RedmineCalendar] Hooks file not found: #{hooks_path}"
    end
    
    # Load controller patch
    patch_path = File.join(plugin_dir, 'lib', 'redmine_calendar', 'calendars_controller_patch.rb')
    if File.exist?(patch_path)
      require patch_path
      
      # Apply patch
      if defined?(CalendarsController) && defined?(RedmineCalendar::CalendarsControllerPatch)
        CalendarsController.include(RedmineCalendar::CalendarsControllerPatch)
        Rails.logger.info "[RedmineCalendar] Controller patch applied successfully"
      else
        Rails.logger.error "[RedmineCalendar] Could not apply controller patch"
      end
    else
      Rails.logger.error "[RedmineCalendar] Patch file not found: #{patch_path}"
    end
    
    Rails.logger.info "[RedmineCalendar] Plugin initialization complete (v1.0.4)"
    
  rescue => e
    Rails.logger.error "[RedmineCalendar] Failed to initialize plugin: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

Rails.logger.info "[RedmineCalendar] Plugin registered (v1.0.4)" if defined?(Rails.logger)