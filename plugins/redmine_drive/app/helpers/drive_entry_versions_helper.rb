# encoding: utf-8
#
# This file is a part of Redmin Drive (redmine_drive) plugin,
# Filse storage plugin for redmine
#
# Copyright (C) 2011-2025 RedmineUP
# http://www.redmineup.com/
#
# redmine_drive is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_drive is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_drive.  If not, see <http://www.gnu.org/licenses/>.

module DriveEntryVersionsHelper
  def render_drive_versions(drive_entry)
    last = drive_entry.last_version
    grouped_copies = drive_entry.versions.order(created_at: :desc)
                                .group_by { |copy| copy.created_at.to_date }

    grouped_copies.each_with_index.map do |group_values, index|
      date, group = group_values
      group_label = "drive-versions-date-#{index}"
      content_tag(:div, id: group_label) do
        current_group = group.include?(drive_entry)
        date_label(distance_of_versions_date_in_words(Date.today, date), group.count, group_label, current_group) +
        content_tag(:div, class: "versions-wrapper #{'hide' unless current_group }") do
          concat group.map { |entry| drive_version_label(entry, drive_entry, last) }.join.html_safe
        end
      end
    end.join.html_safe
  end

  def date_label(date, count, group_label, current_group)
    content_tag('h4') do
      link_to("#{date} (#{count})",
              '#',
              class: "versions-date icon collapsible #{ current_group ? 'icon-expended icon-expanded' : 'icon-collapsed'}",
              onclick: "toogleDriveVersionsDate('#{group_label}')")
    end
  end

  def drive_version_label(entry, selected, last)
    content_tag(:div, class: 'version') do
      content_tag(:div, class: 'version_image') do
        avatar(entry.author)
      end +
      content_tag(:div, class: 'version_data') do
        content_tag(:strong, "v#{entry.version} - ") + drive_entry_link(entry, selected, last)
      end
    end
  end

  def drive_entry_link(entry, selected, last)
    link_text = ''
    if entry != selected
      link_text += link_to_drive_entry(entry.attachment, text: drive_entry_link_text(entry), title: entry.full_path)
      link_text += drive_entry_version_name_label(entry)
    else
      link_text += drive_entry_link_text(entry)
      link_text += drive_entry_version_name_label(entry)
      link_text += link_to_drive_entry(entry.last_version.attachment, text: '', class: 'icon-only icon-clear-query') if entry != last

    end
    link_text.html_safe
  end

  def distance_of_versions_date_in_words(from, to)
    from = from.to_date if from.respond_to?(:to_date)
    to = to.to_date if to.respond_to?(:to_date)
    distance = (to - from).abs

    return l(:label_drive_version_today) if distance == 0
    return l(:label_drive_version_yesterday) if distance == 1

    l(:label_drive_days_ago, days: distance.to_i)
  end

  def drive_entry_link_text(entry)
    [content_tag(:strong, format_time(entry.created_at)),
     entry.author.name(User.name_formatter)].join(' - ').html_safe
  end

  def drive_entry_version_name_label(entry)
    entry.version_name ? [',', content_tag(:span, entry.version_name)].join(' ') : ''
  end
end
