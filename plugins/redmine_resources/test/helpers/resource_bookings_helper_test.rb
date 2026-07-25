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

class ResourceBookingsHelperTest < ActionView::TestCase
  include ResourceBookingsHelper

  fixtures :projects, :users

  def setup
    @project = Project.find(1)
    @admin = User.find(1)
    @query_private = ResourceBookingQuery.create!(name: 'Private Query', project: @project, user: @admin, visibility: ResourceQuery::VISIBILITY_PRIVATE)
    @query_public = ResourceBookingQuery.create!(name: 'Public Query', project: @project, user: @admin, visibility: ResourceQuery::VISIBILITY_PUBLIC)
  end
end
