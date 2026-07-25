require 'redmine'

begin
  require_relative './lib/details_issue_hooks.rb'
rescue StandardError => e
  Rails.logger.error "[redmine_issue_edit_online] Failed to load details_issue_hooks.rb: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  raise e
end

Redmine::Plugin.register :redmine_issue_edit_online do
  name 'Redmine Issue Edit Online'
  author 'carolcoral'
  description 'Allows users to dynamically update issue attributes in detailed view without refreshing the page (JIRA style)'
  version '1.0.0'
  author_url 'https://github.com/carolcoral'
  settings default: {
    'visual_editor_mode_switch_tab' => '',
    'force_https' => false,
    'display_edit_icon' => 'single',
    'listener_type_value' => 'click',
    'listener_type_icon' => 'click',
    'listener_target' => 'value',
    'excluded_field_id' => '',
    'check_issue_update_conflict' => true
  },
           partial: 'redmine_issue_edit_online/settings'
end
