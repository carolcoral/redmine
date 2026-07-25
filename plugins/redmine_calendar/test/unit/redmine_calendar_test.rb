require File.expand_path('../../../test/test_helper', __dir__)

class RedmineCalendarTest < ActiveSupport::TestCase
  fixtures :projects, :users, :issues, :trackers, :issue_statuses

  def setup
    @project = Project.find(1)
    @user = User.find(1)
    User.current = @user
  end

  def test_plugin_loaded
    assert Redmine::Plugin.registered_plugins[:redmine_calendar]
  end

  def test_permissions_registered
    assert Redmine::AccessControl.permission?(:edit_calendar_issues)
  end

  def test_hooks_registered
    assert Redmine::Hook.hook_listeners[:view_layouts_base_html_head].any? { |l| l.to_s.include?('RedmineCalendar') }
  end
end