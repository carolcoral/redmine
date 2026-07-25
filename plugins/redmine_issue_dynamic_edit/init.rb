require 'redmine'

require_relative './lib/details_issue_hooks.rb'

Redmine::Plugin.register :redmine_issue_dynamic_edit do
  name 'Redmine Dynamic edit Issue plugin'
  author 'Hugo Zilliox'
  description 'Allows users to dynamically update issue attributes in detailed view without refreshing the page (JIRA style)'
  version '1.0.0'
  author_url 'https://hzilliox.fr'
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
           partial: 'redmine_issue_dynamic_edit/settings'
end
