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

class ResourceBookingQueryTest < ActiveSupport::TestCase

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

  def test_resource_bookings_between_dates
    ResourceBooking.delete_all
    ResourceBooking.create(start_date: '2018-12-05', end_date: '2018-12-10', project: @project, assigned_to: @user)
    ResourceBooking.create(start_date: '2018-12-20', end_date: '2018-12-25', project: @project, assigned_to: @user)
    from_date = '2018-12-01'.to_date
    to_date = '2018-12-31'.to_date

    query = ResourceBookingQuery.new
    results = query.resource_bookings_between(from_date, to_date)

    assert results.all? { |booking| booking.start_date >= from_date && booking.end_date <= to_date }, "Bookings should be within date range"
  end

  def test_chart_type_assignment
    query = ResourceBookingQuery.new

    query.chart_type = ResourceBookingQuery::ALLOCATION_CHART
    assert query.allocation_chart?
  end

  def test_allocation_chart_class_selection
    query = ResourceBookingQuery.new
    query.chart_type = ResourceBookingQuery::ALLOCATION_CHART

    assert_equal RedmineResources::Charts::AllocationChart, query.chart_class
  end

  def test_resource_bookings_by_issue_id
    booking_issue = Issue.find(1)
    start_date = '2023-01-05'
    end_date = '2023-01-10'
    ResourceBooking.create(start_date: start_date, end_date: end_date, project: @project, assigned_to: @user, issue_id: booking_issue.id)
    from_date = start_date.to_date.beginning_of_month
    to_date = end_date.to_date.end_of_month

    query = ResourceBookingQuery.new
    query.add_filter('issue_id', '=', [booking_issue.id.to_s])
    results = query.resource_bookings_between(from_date, to_date)

    results.each do |booking|
      assert_equal booking_issue.id, booking.issue_id, 'Returned bookings should match the specified issue_id'
    end
  end
end
