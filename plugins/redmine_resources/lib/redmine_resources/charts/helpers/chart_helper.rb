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

module RedmineResources
  module Charts
    module Helpers
      module ChartHelper
        RED_BAR = 'red_bar'.freeze
        YELLOW_BAR = 'yellow_bar'.freeze
        GREEN_BAR = 'green_bar'.freeze

        def render_load_tooltip(load_hours, workday_length)
          @cached_label_load ||= l(:label_resources_load)
          @cached_label_full_load ||= l(:label_resources_full_load)
          @cached_label_overload ||= l(:label_resources_overload)
          @cached_label_underload ||= l(:label_resources_underload)

          @cached_label_total_scheduled ||= l(:label_resources_total_scheduled)
          @cached_label_total ||= l(:label_total)

          s =
            if load_hours == 0
              "<strong>#{@cached_label_load}</strong>: #{@cached_label_full_load}<br />"
            elsif load_hours > 0
              new_load_tooltip_line(@cached_label_underload, load_hours)
            else
              new_load_tooltip_line(@cached_label_overload, load_hours.abs)
            end

          s << '<br />'
          s << new_load_tooltip_line(@cached_label_total_scheduled, workday_length - load_hours)
          s << new_load_tooltip_line(@cached_label_total, workday_length)

          s.html_safe
        end

        def new_load_tooltip_line(label, hours)
          "<strong>#{label}</strong>: #{l(:label_resources_f_hour_short, value: to_int_if_whole(hours))}<br />"
        end

        def render_resource_booking_tooltip(resource_booking, workday_count = nil)
          render_resource_booking_attributes(resource_booking, true, '<br />'.html_safe, workday_count)
        end

        def render_resource_booking_attributes(resource_booking, html = false, empty_line = ''.html_safe, workday_count = nil)
          s = render_attributes(tooltip_resource_booking_attributes(resource_booking, workday_count), html)

          if resource_booking.is_a?(Issue)
            s << empty_line + render_tooltip_issue_attributes(resource_booking, html)
          elsif resource_booking.issue
            s << empty_line + render_tooltip_issue_attributes(resource_booking.issue, html)
          end

          if resource_booking.notes.present?
            @cached_label_notes ||= l(:field_notes)
            s << empty_line + render_attributes([{ name: @cached_label_notes, value: resource_booking.notes }], html)
          end

          s
        end

        def tooltip_resource_booking_attributes(resource_booking, workday_count = nil)
          @cached_label_dates ||= l(:label_resources_dates)
          @cached_label_scheduled ||= l(:label_resources_scheduled)
          @cached_label_total ||= l(:label_total)
          if resource_booking.is_a?(Issue)
            issue = resource_booking
            hours_per_day = issue.hours_per_day
            working_days_amount = issue.working_days_amount
            non_working_days_amount = issue.non_working_days_amount
            attributes = [{ name: @cached_label_dates, value: dates_range_label(resource_booking.start_date, resource_booking.due_date, '%a, %d %b') }]
          else
            hours_per_day = resource_booking.booking_value if resource_booking.booking_type == 'hours'
            percent = resource_booking.booking_value if resource_booking.booking_type == 'percent'
            working_days_amount = workday_count || resource_booking.working_days_amount
            non_working_days_amount = resource_booking.total_days - working_days_amount

            attributes = [{ name: @cached_label_dates, value: dates_range_label(resource_booking.start_date, resource_booking.get_end_date, '%a, %d %b') }]
          end

          if hours_per_day
            attributes << { name: @cached_label_scheduled, value: scheduled_label(hours_per_day, working_days_amount, non_working_days_amount) }
            attributes << { name: @cached_label_total, value: total_scheduled_label(hours_per_day, working_days_amount, non_working_days_amount) }
          end

          if percent
            attributes << { name: @cached_label_scheduled, value: "#{percent} %" }
            attributes << { name: @cached_label_total, value: scheduled_label_end(working_days_amount, non_working_days_amount) }
          end

          attributes
        end

        def scheduled_label(hours_per_day, working_days_amount, non_working_days_amount)
          @cached_label_hours_per_day_abbreviation ||= l(:field_hours_per_day_abbreviation)

          "#{to_int_if_whole(hours_per_day)} #{@cached_label_hours_per_day_abbreviation}" +
            scheduled_label_end(working_days_amount, non_working_days_amount)
        end

        def total_scheduled_label(hours_per_day, working_days_amount, non_working_days_amount)
          l('datetime.distance_in_words.x_hours', to_int_if_whole(working_days_amount * hours_per_day)) +
            scheduled_label_end(working_days_amount, non_working_days_amount)
        end

        def scheduled_label_end(working_days_amount, non_working_days_amount)
          @cached_label_scheduled_for ||= l(:label_resources_scheduled_for)

          s = " #{@cached_label_scheduled_for} " + l('datetime.distance_in_words.x_days', working_days_amount)
          s << " (#{l(:label_resources_x_day_off, non_working_days_amount)})" if non_working_days_amount > 0
          s
        end

        def tooltip_issue_attributes(issue, options = {})
          @cached_label_issue ||= l(:label_issue)
          @cached_label_status ||= l(:field_status)
          @cached_label_start_date ||= l(:field_start_date)
          @cached_label_due_date ||= l(:field_due_date)
          @cached_label_assigned_to ||= l(:field_assigned_to)
          @cached_label_priority ||= l(:field_priority)
          @cached_label_project ||= l(:field_project)
          @cached_label_author ||= l(:field_author)

          options = { only_path: true }.merge(options)

          [{ name: @cached_label_issue,       value: link_to_issue(issue, only_path: options[:only_path]) },
           { name: @cached_label_project,     value: link_to_project(issue.project, only_path: options[:only_path]) },
           { name: @cached_label_status,      value: h(issue.status.name) },
           { name: @cached_label_start_date,  value: format_date(issue.start_date) },
           { name: @cached_label_due_date,    value: format_date(issue.due_date) },
           { name: @cached_label_assigned_to, value: h(issue.assigned_to) },
           { name: @cached_label_author,      value: h(issue.author) }]
        end

        def render_tooltip_issue_attributes(issue, html = false)
          render_attributes(tooltip_issue_attributes(issue), html)
        end

        def show_more_time_entries_link(date, project, issue, user = User.current)
          url_options = { controller: 'timelog', action: 'index', set_filter: 1, f: [], op: {}, v: {} }
          add_filter_options_to(url_options, :spent_on, '=', [date])

          if issue.blank?
            add_filter_options_to(url_options, :project_id, '=', [project.id])
          else
            add_filter_options_to(url_options, :issue_id, '=', [issue.id])
          end

          add_filter_options_to(url_options, :user_id, '=', [user.id])

          link_to l(:label_resources_show_more), url_options
        end

        def time_entry_activity_link(time_entry)
          url_options = { controller: 'timelog', action: 'index', set_filter: 1, f: [], op: {}, v: {} }
          add_filter_options_to(url_options, :spent_on, '=', [time_entry.spent_on])

          if time_entry.issue_id
            add_filter_options_to(url_options, :issue_id, '=', [time_entry.issue_id])
          else
            add_filter_options_to(url_options, :project_id, '=', [time_entry.project_id])
          end

          add_filter_options_to(url_options, :user_id, '=', [time_entry.user_id])
          add_filter_options_to(url_options, :activity_id, '=', [time_entry.activity_id])

          link_to time_entry.activity, url_options
        end

        def add_filter_options_to(target, field, operator, values)
          target[:f] << field
          target[:op][field] = operator
          target[:v][field] = values
        end

        def tooltip_time_entry_attributes(time_entry, options = { only_path: true })
          attributes = [{ name: l(:label_activity), value: time_entry_activity_link(time_entry) }]

          if time_entry.issue.present?
            attributes << { name: l(:label_issue), value: link_to_issue(time_entry.issue, only_path: options[:only_path]) }
          end

          attributes << { name: l(:field_comments), value: time_entry.comments.to_s.truncate(100) }
          attributes << { name: l(:field_hours),    value: l(:label_resources_f_hour_short, value: '%0.2f' % time_entry.hours) }
          attributes
        end

        def render_time_entries_tooltip(time_entries, count = 2)
          time_entries.first(count).map do |time_entry|
            render_attributes(tooltip_time_entry_attributes(time_entry), true)
          end.join('<br />')
        end

        def render_attributes(attributes, html = false)
          if html
            attributes.map { |attribute| "<strong>#{attribute[:name]}</strong>: #{attribute[:value]}<br />" }.join("\n").html_safe
          else
            attributes.map { |attribute| "* #{attribute[:name]}: #{attribute[:value]}" }.join("\n")
          end
        end

        def subject_for_user(user)
          content_tag :div, id: "user-#{user.id}", class: 'user-subject' do
            [expander(user), avatar(user, size: '16'), link_to_user(user)].join(' ').html_safe
          end
        end

        def expander(user)
          content_tag(:span, sprite_icon('angle-down'), id: "user-expander-#{user.id}", class: 'expander',
                      onclick: %($('.user-resource-bookings[group_id="#{user.id}"]').toggleClass('open');
                        updateSVGIcon(this, this.closest('.open') ? 'angle-down' : 'angle-right');
                      ))
        end

        def subject_for_unassigned_issues_link(link)
          content_tag :div, class: 'user-subject' do
            [expander_free_issues, link].join(' ').html_safe
          end
        end

        def expander_free_issues
          content_tag(:span, '&nbsp;'.html_safe, class: 'expander',
                      onclick: %($('.user-resource-bookings[group_id="unassigned_issues"]').toggleClass('open');))
        end

        def new_booking_path(project, user, issue, start_date, end_date)
          new_resource_booking_path resource_booking: {
            project_id: project.try(:id),
            assigned_to_id: user,
            issue_id: issue,
            start_date: start_date,
            end_date: end_date
          }, project_id: @project
        end

        def new_path_for(resource_booking)
          new_resource_booking_path resource_booking: {
            project_id: resource_booking.project.id,
            assigned_to_id: resource_booking.assigned_to,
            issue_id: resource_booking.issue,
            start_date: resource_booking.start_date,
            end_date: resource_booking.end_date,
            booking_value: resource_booking.booking_value,
            booking_type: resource_booking.booking_type
          }, project_id: @project
        end

        def edit_path_for(resource_booking)
          return edit_resource_issue_path(resource_booking, project_id: @project) if resource_booking.is_a?(Issue)
          if resource_booking.new_record?
            new_path_for(resource_booking)
          else
            edit_resource_booking_path(resource_booking, project_id: @project)
          end
        end

        def update_path_for(resource_booking)
          return resource_issue_path(resource_booking, project_id: @project) if resource_booking.is_a?(Issue)
          if resource_booking.new_record?
            new_path_for(resource_booking)
          else
            resource_booking_path(resource_booking, project_id: @project)
          end
        end

        def dates_range_label(from, to, format = :short)
          if from == to || !to
            I18n.l(from, format: format)
          else
            I18n.l(from, format: format) + ' - ' + I18n.l(to, format: format)
          end
        end

        def short_month_name(month)
          if I18n.exists?('date.standalone_abbr_month_names')
            I18n.t('date.standalone_abbr_month_names')[month]
          else
            I18n.t('date.abbr_month_names')[month]
          end
        end

        def user_bar_label(load_hours)
          (load_hours == 0) ? 'F' : l(:label_resources_f_hour_short, value: to_int_if_whole(load_hours).round(1))
        end

        def user_bar_label_in_percent(percent)
          percent == 0 ? 'F' : percent.to_s + '%'
        end

        def total_hours_bar_label(resource_booking)
          if resource_booking.try(:booking_value)
            l(:label_f_hour_short, value: to_int_if_whole(resource_booking.total_hours))
          end
        end

        def to_int_if_whole(float_number)
          float_number.to_i == float_number ? float_number.to_i : float_number.round(2)
        end

        def unassigned_issues_path(issues_ids)
          issues_filter = { set_filter: '1', issue_id: issues_ids.join(',') }
          @project ? project_issues_path(issues_filter, @project) : issues_path(issues_filter)
        end

        def task_bar_color_class(load_hours)
          if load_hours == 0
            YELLOW_BAR
          elsif load_hours > 0
            GREEN_BAR
          else
            RED_BAR
          end
        end

        def task_bar_percent_workload_color_class(percent)
          if percent < 95
            GREEN_BAR
          elsif percent > 100
            RED_BAR
          else
            YELLOW_BAR
          end
        end
      end
    end
  end
end
