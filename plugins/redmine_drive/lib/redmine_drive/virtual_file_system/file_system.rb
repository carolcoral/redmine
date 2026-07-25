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

require 'zip'

module RedmineDrive
  module VirtualFileSystem
    module FileSystem
      def self.root_folder
        RootFolder.new
      end

      def self.project_folders
        RedmineDrive.projects
                    .map { |project| ProjectFolder.new(project) if User.current.allowed_to?(:view_drive_entries, project) }
                    .compact
      end

      def self.virtual_folders
        [root_folder] + project_folders
      end

      def self.find_folder(id)
        folder = virtual_folders.detect { |folder| folder.id == id } || DriveEntry.find(id)
        folder if folder.folder?
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def self.find_current_folder(id = nil, project = nil)
        if id
          find_folder(id)
        elsif project
          ProjectFolder.new(project)
        else
          root_folder
        end
      end

      def self.find_virtual_folders(ids)
        virtual_folders.select do |folder|
          ids.detect { |id| folder.id == id }
        end
      end

      def self.find_drive_entries(ids)
        return if ids.blank?

        find_virtual_folders(ids) + DriveEntry.includes(:attachment).where(id: ids).to_a
      end

      def self.parent_for(drive_entry)
        if drive_entry.is_a?(VirtualFolder) || drive_entry.parent
          drive_entry.parent
        elsif drive_entry.project_id
          ProjectFolder.new(drive_entry.project)
        else
          root_folder
        end
      end

      def self.move_to(folder, drive_entries)
        saved = true
        DriveEntry.transaction do
          select_drive_entries_to_copy(folder, drive_entries).each do |drive_entry|
            drive_entry.versions.each { |entry_version| saved &&= folder.add(entry_version) }

            if drive_entry.children.present?
              saved &&= drive_entry.update_children
            end

            raise ActiveRecord::Rollback unless saved
          end
        end
        saved
      end

      def self.copy_to(folder, drive_entries)
        saved = true
        DriveEntry.transaction do
          select_drive_entries_to_copy(folder, drive_entries).each do |drive_entry|
            copy = drive_entry.copy(parent_id: folder.db_record_id, author: User.current, project: folder.project)
            saved &&= folder.add(copy)

            children = drive_entry.children.includes(:attachment)
            saved &&= copy_to(copy, children) if children.present?

            raise ActiveRecord::Rollback unless saved
          end
        end
        saved
      end

      private

      def self.select_drive_entries_to_copy(folder, drive_entries)
        full_path_ids = (folder.ancestors << folder).map(&:id)
        drive_entries
          .select { |x| full_path_ids.exclude?(x.id) }
          .sort { |a, b| b.basename <=> a.basename }
      end
    end
  end
end
