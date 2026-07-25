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

module ResourceBookingsHelper
  include RedmineResources::Charts::Helpers::ChartHelper

  def warning_messages_for(*objects)
    objects = objects.map { |o| o.is_a?(String) ? instance_variable_get("@#{o}") : o }.compact
    warnings = objects.map { |o| o.warnings.full_messages }.flatten
    render_warning_messages(warnings)
  end

  def render_warning_messages(warnings)
    html = ''
    if warnings.present?
      html << "<div id='warningExplanation' class='warning'><ul>\n"
      warnings.each do |warning|
        html << "<li>#{h warning}</li>\n"
      end
      html << "</ul></div>\n"
    end
    html.html_safe
  end

  def chart_type_options
    options = ResourceBookingQuery::CHART_TYPES.map { |x| [l("label_resources_#{x}"), x] }

    options << [l(:label_resources_allocation_table_pro), :pro]
    options << [l(:label_resources_issues_chart_pro), :pro]
    options << [l(:label_resources_utilization_report_pro), :pro]
    options
  end

  def workload_type_options
    ResourceBookingQuery::WORKLOAD_TYPES.map { |x| [l("label_resources_workload_in_#{x}"), x] }
  end

  def zoom_options
    options = ResourceBookingQuery::SCALES.map { |x| [l("label_resources_#{x}_scale"), x] }
    options << [l(:label_resources_1_scale) + '(PRO)', :pro]
    options << [l(:label_resources_2_scale) + '(PRO)', :pro]
    options
  end

  def line_title_type_options
    options = RedmineResources::Charts::AllocationChart::LINE_TITLE_TYPES.map { |x| [l("label_resources_#{x}"), x] }
    options << [l(:label_resources_issue_subject_pro), :pro]
    options << [l(:label_resources_hours_per_day_pro), :pro]
    options
  end

  def issue_title_type_options
    options = [RedmineResources::Charts::ResourceIssuesChart::ISSUE_SUBJECT].map { |x| [l("label_resources_#{x}"), x] }
    options << [l(:label_resources_issue_subject_pro), :pro]
    options
  end

  def custom_options_for_select(options, selected_option)
    options_for_select(options,
                       disabled: :pro,
                       selected: selected_option)
  end

  def check_box_with_label(value, label, disabled = false)
    value = :pro
    label = "#{label}_pro"
    disabled = true
    check_box('query', value, id: value, disabled: disabled) + l(label)
  end

  if Redmine::VERSION.to_s < '4.1'
    def link_to_previous_month(year, month, options={})
      target_year, target_month = if month == 1
                                    [year - 1, 12]
                                  else
                                    [year, month - 1]
                                  end

      name = if target_month == 12
              "#{month_name(target_month)} #{target_year}"
            else
              month_name(target_month)
            end

      link_to_month(("« " + name), target_year, target_month, options)
    end

    def link_to_next_month(year, month, options={})
      target_year, target_month = if month == 12
                                    [year + 1, 1]
                                  else
                                    [year, month + 1]
                                  end

      name = if target_month == 1
              "#{month_name(target_month)} #{target_year}"
            else
              month_name(target_month)
            end

      link_to_month((name + " »"), target_year, target_month, options)
    end

    def link_to_month(link_name, year, month, options={})
      link_to(link_name, {:params => request.query_parameters.merge(:year => year, :month => month)}, options)
    end
  end

  def link_to_previous_year(year, options={})
    link_to((year - 1).to_s, {:params => request.query_parameters.merge(:year => year - 1)}, options)
  end

  def link_to_next_year(year, options={})
    link_to((year + 1).to_s, {:params => request.query_parameters.merge(:year => year + 1)}, options)
  end

  def link_to_previous_week(date, options={})
    link_to(l(:label_previous), {:params => request.query_parameters.merge(:date_from => date - 1.week)}, options)
  end

  def link_to_next_week(date, options={})
    link_to(l(:label_next), {:params => request.query_parameters.merge(:date_from => date + 1.week)}, options)
  end

  def gray_hint(id, issue_attr=nil)
    if ['user_workload', 'days_count', 'dayoffs_count_hint', 'issue_dates', 'total_hours_hint'].include?(id)
      translation = l("label_resources_#{id}")
      if id == 'issue_dates'
        start_date, due_date = issue_attr.values
        issue_attr = start_date ? l("label_resources_#{id}", start_date: start_date, due_date: due_date) : ''
      end

      if id == 'user_workload'
        content_tag(:em, issue_attr, id: id, class: 'info hint', data: { translation: translation, short_time_format: l(:label_resources_short_time_format) })
      else
        content_tag(:em, issue_attr, id: id, class: 'info hint', data: { translation: translation })
      end
    else
      content_tag(:em, issue_attr, id: id, class: 'info hint')
    end
  end

  def bookings_index_path
    @project ? project_resource_bookings_path(project_id: @project) : resource_bookings_path
  end

  def color_css_class(percent)
    if percent < 95
      'green'
    elsif percent > 100
      'red'
    else
      'full'
    end
  end
end
