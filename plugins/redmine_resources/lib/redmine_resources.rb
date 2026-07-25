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
  include Redmine::I18n
  extend Redmine::Utils::DateCalculation

  WORKDAY = :workday
  WEEKEND = :weekend

  def self.settings() Setting.plugin_redmine_resources end

  def self.default_workday_length
    (people_plugin_installed? ? Setting.plugin_redmine_people : settings)['workday_length'].to_f
  end

  def self.workday_length
    settings['workday_length'].to_f
  end

  def self.people_plugin_installed?
    @@people_plugin_installed ||= (Redmine::Plugin.installed?(:redmine_people) && Redmine::Plugin.find(:redmine_people).version >= '1.4.0')
  end

  def self.people_pro_plugin_installed?
    @@people_pro_plugin_installed ||= Redmine::Plugin.installed?(:redmine_people) &&
                                      Gem::Version.new(Redmine::Plugin.find(:redmine_people).version) >= Gem::Version.new('1.6.8') &&
                                      Redmine::Plugin.find(:redmine_people).name.include?('PRO version')
  end

  # Return the first day of week
  # 1 = Monday ... 7 = Sunday
  def self.first_wday
    if Setting.start_of_week.blank?
      (l(:general_first_day_of_week).to_i - 1)%7 + 1
    else
      Setting.start_of_week.to_i
    end
  end

  def self.user_capacity(user, start_date, end_date)
    if people_pro_plugin_installed?
      person = user.becomes(Person)
      work_hours_hash = Dayoff.person_work_hours_per_day(person, start_date, end_date, person&.workday_length)
      work_hours_hash.values.sum
    else
      global_work_days(start_date, end_date).size * default_workday_length
    end
  end

  def self.users_capacity_map(users_ids, date_from, date_to)
    if people_pro_plugin_installed?
      Person.users_capacity_map(users_ids, date_from, date_to)
    else
      person_capacity_hash = (date_from..date_to).each_with_object({}) do |date, person_capacity_hash|
        if non_working_week_days.include?(date.cwday)
          person_capacity_hash[date] = { day_type: WEEKEND, workday_length: 0 }
        else
          person_capacity_hash[date] = { day_type: WORKDAY, workday_length: RedmineResources.default_workday_length }
        end
      end

      users_ids.each_with_object({}) do |user_id, user_capacity_map|
        user_capacity_map[user_id] = person_capacity_hash
      end
    end
  end

  def self.global_work_days(start_date, end_date)
    workdays = []
    (start_date.to_date..end_date.to_date).each do |date|
      unless non_working_week_days.include?(date.cwday)
        workdays << date
      end
    end
    workdays
  end

  def self.sum_date_hash_by_period(date_hash, period)
    sums_by_period = Hash.new(0)

    date_hash.each do |date, sum|
      case period
      when :week
        period_value = date.cweek
      when :month
        period_value = date.month
      when :quarter
        period_value = (date.month - 1) / 3 + 1
      when :year
        period_value = date.year
      else
        raise ArgumentError, "Invalid period: #{period}"
      end
      sums_by_period[period_value] += sum
    end

    sums_by_period
  end

  def self.person_workload_array(person, start_date, end_date)
    
  end


  def self.beginning_of_week(user = User.current)
    user.today.beginning_of_week(Date::DAYS_INTO_WEEK.key(first_wday - 1))
  end
end

REDMINE_RESOURCES_REQUIRED_FILES = [
  'redmine_resources/hooks/views_layouts_hook',
  'redmine_resources/patches/issue_patch',
  'redmine_resources/patches/notifiable_patch',
  'redmine_resources/charts/helpers/chart_helper',
  'redmine_resources/charts/allocation_chart'
]

base_url = File.dirname(__FILE__)
REDMINE_RESOURCES_REQUIRED_FILES.each { |file| require(base_url + '/' + file) }
