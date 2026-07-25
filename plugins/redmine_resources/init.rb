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

requires_redmineup version_or_higher: '1.0.10' rescue raise "\n\033[31mRedmine requires newer redmineup gem version.\nPlease update with 'bundle update redmineup'.\033[0m"

RESOURCES_VERSION_NUMBER = '2.0.6'
RESOURCES_VERSION_TYPE = "Light version"

Redmine::Plugin.register :redmine_resources do
  name "Redmine Resources plugin (#{RESOURCES_VERSION_TYPE})"
  author 'RedmineUP'
  description 'Resource allocation and management for Redmine'
  version RESOURCES_VERSION_NUMBER
  url 'https://www.redmineup.com/pages/plugins/resources'
  author_url 'mailto:support@redmineup.com'

  requires_redmine version_or_higher: '4.0'

  settings default: { 'workday_length' => 8 }, partial: 'settings/resource_bookings/index'

  project_module :resources do
    permission :view_resources, { resource_bookings: [:index, :show] }
    permission :view_resource_issues, { resource_issues: :index }
    permission :add_booking, { resource_bookings: [:new, :create] }
    permission :edit_booking, { resource_bookings: [:edit, :update, :destroy, :split] }
    permission :edit_resource_issues, { resource_issues: [:edit, :update] }
    permission :save_resource_queries, {}, require: :loggedin
    permission :manage_public_resource_queries, {}, require: :member
  end

  menu :top_menu, :resources,
       { controller: 'resource_bookings', action: 'index', project_id: nil }, caption: :label_resources,
       if: Proc.new { User.current.allowed_to?(:view_resources, nil, global: true) }

  menu :application_menu, :resources,
       { controller: 'resource_bookings', action: 'index' }, caption: :label_resources, after: :gantt,
       if: Proc.new { User.current.allowed_to?(:view_resources, nil, global: true) }

  menu :project_menu, :resources,
       { controller: 'resource_bookings', action: 'index' }, caption: :label_resources, after: :gantt, param: :project_id

  activity_provider :resource_bookings, default: false, class_name: 'ResourceBooking'
end

if (Rails.configuration.respond_to?(:autoloader) && Rails.configuration.autoloader == :zeitwerk) || Rails.version > '7.0'
  Rails.autoloaders.each { |loader| loader.ignore(File.dirname(__FILE__) + '/lib') }
  require File.dirname(__FILE__) + '/lib/redmine_resources'
else
  require 'redmine_resources'
end

require 'redmineup/patches/compatibility_patch'
