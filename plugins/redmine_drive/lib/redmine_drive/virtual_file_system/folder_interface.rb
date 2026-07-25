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

module RedmineDrive
  module VirtualFileSystem
    module FolderInterface
      def directory_entries
        @directory_entries ||= children.to_a
      end

      def folders
        @folders ||= directory_entries.select(&:folder?)
      end

      def files
        @files ||= directory_entries.select(&:file?)
      end

      def add(child, options = {})
        options = { resolve_conflicts_mode: :save_new_version }.merge(options)
        assign_drive_entry_attributes(child, parent_id: db_record_id, project: project, parent_folder: self)

        if options[:resolve_conflicts_mode] == :save_both
          child.increment_name until valid_name_of?(child)
        end

        if options[:resolve_conflicts_mode] == :save_new_version
          child.increment_version if child.new_record?
        end

        saved = child.save
        add_child(child) if saved
        saved
      end

      def update_children
        saved = true
        DriveEntry.transaction do
          children.each do |drive_entry|
            saved &&= update_drive_entry(drive_entry, parent_id: db_record_id, project: drive_entry.parent.project, parent_folder: self)

            if drive_entry.children.present?
              saved &&= drive_entry.update_children
            end

            raise ActiveRecord::Rollback unless saved
          end
        end
        saved
      end

      def add_files(attachments, options = {})
        return if attachments.blank?

        saved = true
        DriveEntry.transaction do
          attachments.map do |attachment|
            saved &&= add(build_drive_entry(attachment), options)
            raise ActiveRecord::Rollback unless saved
          end
        end
        saved
      end

      def valid_name_of?(child)
        folders.map(&:name).exclude?(child.name) if child.folder?
      end

      def rollback(child)
        saved = true
        DriveEntry.transaction do
          saved &&= add(build_drive_entry(child.attachment.copy))
        end
        saved
      end

      private

      def build_drive_entry(attachment)
        description = attachment.description
        attachment.description = nil

        DriveEntry.new(
          author: User.current,
          name: attachment.filename,
          attachment: attachment,
          description: description
        )
      end

      def assign_drive_entry_attributes(child, options = {})
        options.each { |k, v| child.send("#{k}=", v) }
      end

      def update_drive_entry(child, options = {})
        assign_drive_entry_attributes(child, options)
        child.save
      end

      def add_child(child)
        directory_entries << child
        folders << child
        files << child
      end
    end
  end
end
