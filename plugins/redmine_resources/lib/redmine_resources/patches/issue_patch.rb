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

module RedmineResources
  module Patches
    module IssuePatch
      SELECT2_ISSUES_LIMIT = 10

      GROUP_ASSIGNED_TO_USER = :assigned_to_user
      GROUP_NOT_ASSIGNED_TO_USER = :not_assigned_to_user
      GROUP_CLOSED_ISSUES = :closed_issues

      ISSUES_GROUPS = {
        GROUP_ASSIGNED_TO_USER => { name: :label_resources_assigned_to_user, order: 0 },
        GROUP_NOT_ASSIGNED_TO_USER => { name: :label_resources_not_assigned_to_user, order: 1 },
        GROUP_CLOSED_ISSUES => { name: :label_resources_closed_issues, order: 2 }
      }.freeze

      def self.included(base)
        base.class_eval do
          extend ClassMethods
          include InstanceMethods

          has_one :resource_booking
          before_destroy :remove_related_resource_bookings

          scope :select_with_sorting_by_groups, lambda { |assigned_to_id|
            group_order_sql = <<-SQL.squish
              CASE
                WHEN #{IssueStatus.table_name}.is_closed = #{Issue.connection.quoted_true} THEN #{group_order_for(GROUP_CLOSED_ISSUES)}
                WHEN #{Issue.table_name}.assigned_to_id = #{assigned_to_id} THEN #{group_order_for(GROUP_ASSIGNED_TO_USER)}
                ELSE #{group_order_for(GROUP_NOT_ASSIGNED_TO_USER)}
              END group_order
            SQL
            select("#{Issue.table_name}.*, #{group_order_sql}").joins(:status).order('group_order')
          }
        end
      end

      module InstanceMethods
        def find_group_by(user)
          if self[:group_order]
            get_group_by_order(self[:group_order].to_i)
          else
            get_group_by_user(user)
          end
        end

        def get_group_by_order(group_order)
          ISSUES_GROUPS.each { |k, v| return k if v[:order] == group_order }
          raise ArgumentError.new("value must be one of: #{ISSUES_GROUPS.map { |k, v| v[:order] }.join(', ')}")
        end

        def get_group_by_user(user)
          if self.closed?
            GROUP_CLOSED_ISSUES
          else
            self.assigned_to_id == user.id ? GROUP_ASSIGNED_TO_USER : GROUP_NOT_ASSIGNED_TO_USER
          end
        end

        def remove_related_resource_bookings
          ResourceBooking.where(issue_id: id).destroy_all
        end

        def hours_per_day
          if due_date && estimated_hours
            workdays_count = (start_date..due_date).to_a.count { |date| non_working_week_days.exclude?(date.cwday) }
            workdays_count == 0 ? 0 : (estimated_hours / workdays_count).round(2)
          elsif estimated_hours
            workdays_count = working_days_amount == 0 ? 1 : working_days_amount
            (estimated_hours / workdays_count).round(2)
          else
            workday_length.round(2)
          end
        end

        def end_date_by_available_attribute
          due_date_by_workday_length = start_date + (estimated_hours / workday_length).floor.days if estimated_hours && workday_length > 0
          end_date_by_available_attribute = due_date || due_date_by_workday_length || start_date
        end

        def working_days_amount
          (start_date..end_date_by_available_attribute).to_a.count { |date| non_working_week_days.exclude?(date.cwday) }
        end

        def non_working_days_amount
          (start_date..end_date_by_available_attribute).to_a.count { |date| non_working_week_days.include?(date.cwday) }
        end

        def total_hours
          # TODO: Use resource booking example
          working_days_amount.zero? ? 0 : (estimated_hours || working_days_amount * hours_per_day)
        end

        private

        def workday_length
          if assigned_to_id? && RedmineResources.people_plugin_installed?
            assigned_to.respond_to?(:workday_length) ? assigned_to.workday_length : RedmineResources.workday_length
          else
            RedmineResources.default_workday_length
          end
        end
      end

      module ClassMethods
        def group_label_for(group)
          ISSUES_GROUPS[group][:name]
        end

        def group_order_for(group)
          ISSUES_GROUPS[group][:order]
        end

        def build_issues_select2_data(issues, user)
          grouped_issues = issues.to_a.sort { |a, b| a.id <=> b.id }.group_by { |issue| issue.find_group_by(user) }

          result = ISSUES_GROUPS.keys.inject([]) do |data, group|
            data << build_select2_group(group, grouped_issues[group]) if grouped_issues[group]
            data
          end

          result.sort { |a, b| a[:order] <=> b[:order] }
        end

        def build_select2_group(group, objects)
          line_through = group == GROUP_CLOSED_ISSUES

          {
            order: group_order_for(group),
            text: l(group_label_for(group)),
            children: objects.map { |o| { id: o.id, text: o.to_s, start_date: o.start_date, due_date: o.due_date, line_through: line_through } }
          }
        end
      end
    end
  end
end

unless Issue.included_modules.include?(RedmineResources::Patches::IssuePatch)
  Issue.send(:include, RedmineResources::Patches::IssuePatch)
end
