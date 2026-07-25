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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::ResourceBookingsTest < Redmine::ApiTest::Base

  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries,
           :email_addresses

  create_fixtures(Redmine::Plugin.find(:redmine_resources).directory + '/test/fixtures/', [:resource_bookings])

  def setup
    Setting.rest_api_enabled = '1'
  end

  # === Getting ResourceBooking ===

  test "GET /resource_bookings.xml should contain total count" do
    compatible_api_request :get, "/resource_bookings", { format: 'xml' }, credentials('admin')
    assert_response :success
    assert_select 'resources[type=array][total_count]'
  end

  test "GET /resource_bookings.xml with nometa param should not contain total count" do
    compatible_api_request :get, "/resource_bookings", { format: 'xml', nometa: '1' }, credentials('admin')
    assert_response :success
    assert_select 'resources[type=array]:not([total_count])'
  end

  test "GET /resource_bookings.xml should have xml media type" do
    compatible_api_request :get, '/resource_bookings', { format: 'xml' }, credentials('admin')
    assert_response :success
    assert_match /application\/(x-)*xml/, @response.content_type
  end

  test "GET /resource_bookings.json should contain total count" do
    compatible_api_request :get, '/resource_bookings', { format: 'json' }, credentials('admin')
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert json['total_count']
  end

  test "GET /resource_bookings.json with nometa param should not contain total count" do
    compatible_api_request :get, "/resource_bookings", { format: 'json', nometa: '1' }, credentials('admin')
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_nil json['total_count']
  end

  test "GET /resource_bookings.json should have json media type" do
    compatible_api_request :get, '/resource_bookings', { format: 'json' }, credentials('admin')
    assert_response :success
    assert_match /application\/json/, @response.content_type
  end

  test "GET /resource_bookings/:id.xml should return resource_booking" do
    compatible_api_request :get, '/resource_bookings/1', { format: 'xml' }, credentials('admin')
    assert_response :success
    assert_match /application\/(x-)*xml/, @response.content_type
    assert_select 'id'
  end

  test "GET /resource_bookings/:id.json should return resource_booking" do
    compatible_api_request :get, '/resource_bookings/1', { format: 'json' }, credentials('admin')
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_match /application\/json/, @response.content_type
    assert json['resource']['id']
  end

  # === Creating ResourceBooking ===

  test "POST /resource_bookings.xml should create a resource" do
    payload = {
        "resource_booking": {
            "project_id": "1",
            "assigned_to_id": "2",
            "issue_id": "1",
            "start_date": "2022-08-01",
            "end_date": "2022-08-05",
            "booking_value": "4",
            "notes": "Some note"
        }
    }

    assert_difference('ResourceBooking.count') do
      compatible_api_request :post, '/resource_bookings.xml', payload, credentials('admin')
    end
    resource = ResourceBooking.last
    assert_equal 1, resource.project_id
    assert_equal 2, resource.assigned_to_id
    assert_equal 1, resource.issue_id
    assert_equal '2022-08-01'.try(:to_date), resource.start_date.try(:to_date)
    assert_equal '2022-08-05'.try(:to_date), resource.end_date.try(:to_date)
    assert_equal 4, resource.booking_value
    assert_equal 'Some note', resource.notes

    assert_response :created
    assert_match /application\/(x-)*xml/, @response.content_type
    assert_select 'resource > id', :text => resource.id.to_s
  end

  test "POST /resource_bookings.json should create a resource" do
    payload = {
        "resource_booking": {
            "project_id": "1",
            "assigned_to_id": "2",
            "issue_id": "1",
            "start_date": "2022-08-01",
            "end_date": "2022-08-05",
            "booking_value": "4",
            "notes": "Some note"
        }
    }
    assert_difference('ResourceBooking.count') do
      compatible_api_request :post, '/resource_bookings.json', payload, credentials('admin')
    end
    resource = ResourceBooking.last
    assert_equal 1, resource.project_id
    assert_equal 2, resource.assigned_to_id
    assert_equal 1, resource.issue_id
    assert_equal '2022-08-01'.try(:to_date), resource.start_date.try(:to_date)
    assert_equal '2022-08-05'.try(:to_date), resource.end_date.try(:to_date)
    assert_equal 4, resource.booking_value
    assert_equal 'Some note', resource.notes

    assert_response :created
    assert_match /application\/json/, @response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal json['resource']['notes'], resource.notes
  end

  # === Updating ResourceBookings ===

  test "PUT /resource_bookings/:id.xml should update resource" do
    payload = {
        :resource_booking => {
            :notes => "An updated note"
        }
    }
    compatible_api_request :put, '/resource_bookings/1.xml', payload, credentials('admin')
    assert_response :success
    resource = ResourceBooking.find(1)
    assert_equal 'An updated note', resource.notes
  end

  test "PUT /resource_bookings/:id.json should update resource" do
    payload = {
        :resource_booking => {
            :notes => "An updated note"
        }
    }
    compatible_api_request :put, '/resource_bookings/1.json', payload, credentials('admin')
    resource = ResourceBooking.find(1)
    assert_equal 'An updated note', resource.notes
  end

  # === Deleting ResourceBookings ===

  test "DELETE /resource_bookings/:id.xml" do
    assert_difference('ResourceBooking.count', -1) do
      compatible_api_request :delete, '/resource_bookings/1', { format: 'xml' }, credentials('admin')

      assert %w[200 204].include?(response.code)
      assert_equal '', response.body
    end
    assert_nil ResourceBooking.find_by_id(1)
  end

  test "DELETE /resource_bookings/:id.json" do
    assert_difference('ResourceBooking.count', -1) do
      compatible_api_request :delete, '/resource_bookings/1', { format: 'json' }, credentials('admin')
      assert %w[200 204].include?(response.code)
      assert_equal '', response.body
    end
    assert_nil ResourceBooking.find_by_id(1)
  end

  # === Handling Exceptions ===

  test "GET /resource_bookings/:id.xml with not exist id should return not found" do
    compatible_api_request :get, '/resource_bookings/5', { format: 'xml' }, credentials('admin')
    assert_equal '404', response.code
  end

  test "GET /resource_bookings/:id.json with not exist id should return not found" do
    compatible_api_request :get, '/resource_bookings/5', { format: 'json' }, credentials('admin')
    assert_equal '404', response.code
  end

  test "PUT /resource_bookings/:id.xml with failed update" do
    payload = {
        :resource_booking => {
            :booking_value => ''
        }
    }
    compatible_api_request :put, '/resource_bookings/1.xml', payload, credentials('admin')
    assert_response 422
    attribute_name = 'Booking value'
    assert_select 'errors error', :text => "#{attribute_name} cannot be blank"
  end

  test "PUT /resource_bookings/:id.json with failed update" do
    payload = {
        :resource_booking => {
            :booking_value => ''
        }
    }
    compatible_api_request :put, '/resource_bookings/1.json', payload, credentials('admin')
    assert_response 422
    json = ActiveSupport::JSON.decode(response.body)
    attribute_name = 'Booking value'
    assert json['errors'].include?("#{attribute_name} cannot be blank")
  end
end
