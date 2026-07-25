# encoding: utf-8
#
# This file is a part of Redmine Resources (redmine_resources) plugin,
# resource allocation and management for Redmine
#
# Copyright (C) 2011-2025 RedmineUP
# http://www.redmineup.com/
#
# redmine_resources is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_resources is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_resources.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path('../../test_helper', __FILE__)

class ResourceQueryTest < ActiveSupport::TestCase

  fixtures :projects, :users, :user_preferences, :roles, :members, :member_roles,
           :issues, :issue_statuses, :issue_relations, :versions, :trackers, :projects_trackers,
           :issue_categories, :enabled_modules, :enumerations, :workflows, :email_addresses

  create_fixtures(Redmine::Plugin.find(:redmine_resources).directory + '/test/fixtures/', [:resource_bookings])

  def setup
    @admin = User.find(1)
    @user = User.find(2)
    @second_user = User.find(3)
    @project = Project.find(1)
    @second_project = Project.find(2)

    EnabledModule.create(project: @project, name: 'resources')
    EnabledModule.create(project: @second_project, name: 'resources')

    # Allow view resources for developers (user 3 in project 1 & user 2 in project 2)
    Role.where(id: [2]).each do |r|
      r.permissions << :view_resources
      r.save
    end
  end

  def test_initial_filters
    query = ResourceQuery.new

    assert_includes query.available_filters.keys, 'assigned_to_id'
    assert_includes query.available_filters.keys, 'project_id'
    assert_includes query.available_filters.keys, 'issue_id'
  end

  def test_initial_filters_in_project
    query = ResourceQuery.new(project: @project)

    assert_includes query.available_filters.keys, 'assigned_to_id'
    assert_includes query.available_filters.keys, 'issue_id'
    assert_not_includes query.available_filters.keys, 'project_id'
  end

  def test_filter_values_for_assigned_to
    query = ResourceQuery.new(project: @project)
    assigned_to_filter = query.available_filters['assigned_to_id']
    values = assigned_to_filter[:values]

    if User.current.logged?
      assert values.any? { |v| v == ['<< me >>', 'me'] || v == ['<< Me >>', 'me'] }
    end

    user_names = values.map { |v| v.first }
    assert_equal user_names.sort, user_names.sort
  end
end
