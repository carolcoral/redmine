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

class ResourceBookingQuery < ResourceQuery
  include Redmine::Utils::DateCalculation

  ALLOCATION_CHART = 'allocation_chart'.freeze
  SCALES = [3]
  attr_accessor :pro
  CHART_TYPES = [ALLOCATION_CHART].freeze

  self.queried_class = ResourceBooking

  def base_scope
    scope = ResourceBooking.visible.joins(:project).includes(:issue, :assigned_to)

    scope.where(statement)
  end

  def resource_bookings_between(from, to)
    base_scope.between(from, to)
  end

  def resource_bookings_by_users(from, to)
    scope = ResourceBooking.between(from, to)
    if has_filter?('assigned_to_id')
      scope = scope.where(sql_by_filter('assigned_to_id', ResourceBooking.table_name, 'assigned_to_id'))
    end
    scope
  end

  def chart_bookings(from, to)
      resource_bookings_between(from, to)
  end

  def months
    options[:months].to_i
  end

  def months=(arg)
    options[:months] = arg
  end

  def chart_type=(arg)
    if CHART_TYPES.include?(arg)
      options[:chart_type] = arg
    else
      raise ArgumentError.new("value must be one of: #{CHART_TYPES.join(', ')}")
    end
  end

  def allocation_chart?
    chart_type == ALLOCATION_CHART
  end

  def utilization_report?
    chart_type == UTILIZATION_REPORT
  end

  def allocation_table?
    chart_type == ALLOCATION_TABLE
  end

  def chart_class
      RedmineResources::Charts::AllocationChart
  end

  def build_from_params(params)
    super
    self.show_project_names = params[:show_project_names] || params.dig(:query, :show_project_names) || '1'
    self.show_spent_time = params[:show_spent_time] || params.dig(:query,:show_spent_time)
    chart_name = params[:chart_type] || params.dig(:query, :chart_type) || ALLOCATION_CHART
    self.chart_type = chart_name == 'issues_chart' ? ALLOCATION_CHART : chart_name
    self.date_from = if params[:year] && params[:month]
                       "#{params[:year]}-#{params[:month]}-01".to_date
                     elsif allocation_chart? && [1, 2].include?(params[:zoom].to_i)
                      params[:date_from] || params.dig(:query, :date_from) || User.current.today.at_beginning_of_month
                     else
                       params[:date_from] || params.dig(:query, :date_from) || RedmineResources.beginning_of_week
                     end

    self.months = params[:months] || params.dig(:query, :months) || 2 if self.chart_type == ALLOCATION_CHART

    self
  end

  def year_from
    date_from.year
  end

  def month_from
    date_from.month
  end

  private

  def line_title_types
    RedmineResources::Charts::AllocationChart::LINE_TITLE_TYPES
  end

  def default_line_title_type
    RedmineResources::Charts::AllocationChart::TOTAL_HOURS
  end
end
