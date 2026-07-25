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

class IssuePatchTest < ActiveSupport::TestCase
  include Redmine::I18n
  include Redmine::Utils::DateCalculation

  fixtures :projects, :issues, :users

  def setup
    @issue_with_start_due_dates_estimated_hours = Issue.create(start_date: 1.day.ago.to_date, due_date: 10.day.from_now.to_date, estimated_hours: 200.0)
    @issue_with_start_date_estimated_hours = Issue.create(start_date: 2.day.ago.to_date, estimated_hours: 0.5)
    @issue_with_only_start_date = Issue.create(start_date: 1.day.ago.to_date)
  end

  def test_hours_per_day
    assert_equal @issue_with_start_date_estimated_hours.estimated_hours, @issue_with_start_date_estimated_hours.hours_per_day
    assert_equal RedmineResources.default_workday_length, @issue_with_only_start_date.hours_per_day
  end

  def test_end_date_by_available_attribute
    assert_equal @issue_with_start_due_dates_estimated_hours.due_date, @issue_with_start_due_dates_estimated_hours.end_date_by_available_attribute

    end_date = @issue_with_start_date_estimated_hours.start_date + (@issue_with_start_date_estimated_hours.estimated_hours / 8.0).floor.days
    assert_equal end_date, @issue_with_start_date_estimated_hours.end_date_by_available_attribute

    assert_equal @issue_with_only_start_date.start_date, @issue_with_only_start_date.end_date_by_available_attribute
  end

  def test_working_days_amount
    start_date, due_date = @issue_with_start_due_dates_estimated_hours.start_date, @issue_with_start_due_dates_estimated_hours.due_date
    assert_equal (start_date..due_date).count { |date| non_working_week_days.exclude?(date.cwday) }, @issue_with_start_due_dates_estimated_hours.working_days_amount

    if non_working_week_days.include?(@issue_with_only_start_date.start_date.cwday)
      assert_equal 0, @issue_with_only_start_date.working_days_amount
    else
      assert_equal 1, @issue_with_only_start_date.working_days_amount
    end
  end

  def test_total_hours
    assert_equal @issue_with_start_due_dates_estimated_hours.estimated_hours, @issue_with_start_due_dates_estimated_hours.total_hours

    if non_working_week_days.include?(@issue_with_start_date_estimated_hours.start_date.cwday)
      assert_equal 0, @issue_with_start_date_estimated_hours.total_hours
    else
      assert_equal @issue_with_start_date_estimated_hours.estimated_hours, @issue_with_start_date_estimated_hours.total_hours
    end

    if non_working_week_days.include?(@issue_with_only_start_date.start_date.cwday)
      assert_equal 0, @issue_with_only_start_date.total_hours
    else
      assert_equal RedmineResources.default_workday_length, @issue_with_only_start_date.total_hours
    end
  end

end
