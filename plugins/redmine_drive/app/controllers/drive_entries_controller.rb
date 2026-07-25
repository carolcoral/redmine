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

class DriveEntriesController < ApplicationController
  menu_item :drive

  before_action :find_optional_project, except: [:show, :download, :tags_autocomplete]
  before_action :find_optional_project_unless_public_request, only: :show

  before_action :find_current_folder, except: [:show, :update, :download, :tags_autocomplete, :version_name_modal, :version_name,
                                               :comment_create, :comment_destroy]
  before_action :find_drive_entries,
                only: [:edit, :bulk_edit, :bulk_update, :destroy, :download, :copy_modal, :copy, :move_modal, :move, :context_menu]

  before_action :issue_shared_files_warning, only: :destroy

  before_action :find_folder, only: [:children, :sub_folders, :copy, :move]

  before_action :find_drive_entry, only: [:share_modal, :update]
  before_action :find_current_drive_entry, only: [:version_name_modal, :version_name, :rollback, :upload_version,
                                                  :comment_create, :comment_destroy]

  before_action :authorize_public, only: [:show, :download]
  before_action :check_child_file_access, only: :download, if: :public_request?
  skip_before_action :check_if_login_required, only: :show, if: :public_request?

  helper :queries
  include QueriesHelper

  helper :sort
  include SortHelper

  include DriveEntriesHelper

  def index
    @drive_entries = drive_entries_by_session
    render(partial: 'index', layout: false) if request.xhr?
  end

  def show
    if public_request?
      return if params[:current_folder_id] && !find_current_folder(params[:current_folder_id])
      public_show
    else
      return unless find_current_folder
      @drive_entries = drive_entries_by_session
      render :index
    end
  end

  def new_folder
    @drive_entry = DriveEntry.new(project: @project, author: User.current, name: l(:label_drive_new_folder))
  end

  def create_folder
    @drive_entry = DriveEntry.new(project: @project, parent_id: @current_folder.db_record_id, author: User.current)
    @drive_entry.parent_folder = @current_folder
    @drive_entry.safe_attributes = params[:drive_entry]

    if @drive_entry.save
      flash[:notice] = l(:notice_successful_create)
      render js: "window.location = '#{current_folder_path}'"
    else
      render :new_folder
    end
  end

  def new_files
    @submit_path = params[:submit_path] ||
                   create_files_drive_entries_path(project_id: @project, current_folder_id: @current_folder.id)
  end

  def create_files
    find_saved_attachments

    if @current_folder.add_files(@saved_attachments)
      flash[:notice] = l(:notice_successful_create)
      render js: "window.location = '#{current_folder_path}'"
    else
      flash.now[:error] = l(:error_save_failed)
      render :new_files
    end
  end

  def rollback
    if @current_folder.rollback(@drive_entry)
      flash[:notice] = l(:notice_successful_create)
    else
      flash.now[:error] = l(:error_rollback_failed)
    end

    redirect_to attachment_url(@drive_entry.attachment, drive_entry: true)
  end

  def upload_version
    find_saved_attachments(filename: @drive_entry.name)

    if @current_folder.add_files(@saved_attachments)
      flash[:notice] = l(:notice_successful_create)
      render js: "window.location = '#{attachment_path(@drive_entry.attachment, drive_entry: true)}'"
    else
      flash.now[:error] = l(:error_save_failed)
      render :new_files
    end
  end

  def edit
    if @drive_entries.size > 1
      render js: "window.location = '#{bulk_edit_path}'"
    else
      @drive_entry = @drive_entries.first
    end
  end

  def share_modal
    respond_to do |format|
      format.js
      format.json { render json: { public_url: public_url_for(@drive_entry, @expiration_date) } }
    end
  end

  def update
    if params[:current_folder_id]
      return if !find_current_folder(params[:current_folder_id])
    else
      @current_folder = RedmineDrive::VirtualFileSystem::FileSystem.root_folder
    end

    drive_entry_copies = @drive_entry.copies
    @drive_entry.safe_attributes = params[:drive_entry]
    copies_updated =
      if @drive_entry.name_changed?
        if new_name_copies(@drive_entry).any?
          increase_version(@drive_entry)
          remove_copies(drive_entry_copies)
        else
          rename_copies(drive_entry_copies)
        end
      else
        true
      end

    if (saved = @drive_entry.save && copies_updated)
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:label_drive_notice_update_error)
    end

    respond_to do |format|
      format.js {
        if saved || params[:drive_entry].try(:has_key?, :shared)
          render js: "reloadPage('#{request.referer || current_folder_path}');"
        else
          render :edit
        end
      }

      format.json { render json: @drive_entry.as_json(except: [:created_at, :updated_at]) }
    end
  end

  def bulk_edit
    render_403 unless check_permission(@drive_entries)
  end

  def bulk_update
    if DriveEntry.update_drive_entries(@drive_entries, params[:drive_entries])
      redirect_back_or_default current_folder_path
    else
      render action: :bulk_edit
    end
  end

  def copy_modal; end

  def copy
    if RedmineDrive::VirtualFileSystem::FileSystem.copy_to(@folder, @drive_entries)
      flash[:notice] = l(:label_drive_notice_copying_completed)
    else
      flash[:error] = l(:label_drive_notice_copying_error)
    end

    render js: "window.location = '#{current_folder_path}'"
  end

  def move_modal; end

  def move
    if RedmineDrive::VirtualFileSystem::FileSystem.move_to(@folder, @drive_entries)
      flash[:notice] = l(:label_drive_notice_move_completed)
    else
      flash[:error] = l(:label_drive_notice_moving_error)
    end

    render js: "window.location = '#{current_folder_path}'"
  end

  def destroy
    @drive_entries.each{ |entry| entry.versions.each(&:destroy) }
    flash[:notice] = l(:notice_successful_delete)
    render js: "window.location = '#{current_folder_path}'"
  end

  def download
    return render_403 unless public_request? || allowed_to_view_with_projects(@drive_entries)

    DriveEntry.increment_files_downloads(@drive_entries, request.remote_addr)

    if @drive_entries.size == 1 && @drive_entries.first.file?
      attachment = @drive_entries.first.attachment
      if stale?(etag: attachment.digest)
        send_file attachment.diskfile,
                  filename: filename_for_content_disposition(attachment.filename),
                  type: detect_content_type(attachment),
                  disposition: 'attachment'
      end
    end
  end

  def children
    retrieve_query
    @query.filters = {}
    sort_init(@query.sort_criteria.empty? ? @query.default_sort_criteria : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      render partial: 'children', locals: {
        query: @query,
        drive_entries: @folder.children_by_query(@query, order: sort_clause),
        parent: @folder,
        offset: @folder.offset_from(@current_folder)
      }
    end
  end

  def sub_folders
    render partial: 'sub_folders', locals: {
      parent: @folder,
      offset: @folder.offset_from(RedmineDrive::VirtualFileSystem::FileSystem.root_folder) + 1,
      sub_folders: @folder.sub_folders
    }
  end

  def context_menu
    @is_drive_entries = is_drive_entry?(@drive_entries)
    @allow_to_edit = check_permission(@drive_entries)
    render layout: false
  end

  def comment_create
    @comment = @drive_entry.comments.build
    @comment.safe_attributes = params[:comment]
    @comment.author = User.current

    if @comment.save
      flash[:notice] = l(:label_comment_added)
    end

    redirect_to attachment_path(@drive_entry.attachment, drive_entry: true)
  end

  def comment_destroy
    @comment = @drive_entry.comments.find(params[:comment_id])

    flash[:notice] = l(:label_comment_delete) if @comment.destroy

    redirect_to attachment_path(@drive_entry.attachment, drive_entry: true)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  private

  def current_folder_path
    folder_path @current_folder
  end

  def bulk_edit_path
    bulk_edit_drive_entries_path(
      ids: params[:ids],
      project_id: @project,
      current_folder_id: @current_folder.id
    )
  end

  def find_optional_project_unless_public_request
    find_optional_project unless public_request?
  end

  def find_current_folder(id = params[:current_folder_id] || params[:id])
    @current_folder = RedmineDrive::VirtualFileSystem::FileSystem.find_current_folder(id, @project)
    @current_folder || render_404
  end

  def find_drive_entry(id = params[:id])
    @drive_entry = DriveEntry.find(id).last_version
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_current_drive_entry(id = params[:id])
    @drive_entry = DriveEntry.find(id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_folder(folder_id = params[:folder_id])
    @folder = RedmineDrive::VirtualFileSystem::FileSystem.find_folder(folder_id)
    @folder || render_404
  end

  def find_drive_entries(ids = params[:ids])
    @drive_entries = RedmineDrive::VirtualFileSystem::FileSystem.find_drive_entries(ids)
    @drive_entries.presence || render_404
  end

  def find_saved_attachments(custom_attributes = {})
    return unless params[:attachments]

    attachments = params[:attachments]
    if attachments.respond_to?(:to_unsafe_hash)
      attachments = attachments.to_unsafe_hash
    end

    attachments = attachments.stringify_keys

    @saved_attachments = attachments.map do |k, v|
      a = Attachment.find_by_token v['token']
      a.filename = v['filename'] unless v['filename'].blank?
      a.content_type = v['content_type'] unless v['content_type'].blank?
      a.description = v['description'].to_s.strip
      a.assign_attributes(custom_attributes) if custom_attributes.any?
      a
    end
  end

  def authorize_public
    return authorize_global unless public_request?

    return unless find_drive_entry

    @drive_entry.public_access_allowed? && valid_token? || render_403
  end

  def valid_token?
    result = @drive_entry.versions_public_tokens(params[:timestamp]).include?(params[:token])

    result
  end

  def public_request?
    params.key? :token
  end

  def check_child_file_access
    child_file_access(@drive_entry, @drive_entries) || render_403
  end

  def child_file_access(drive_entry, drive_entries)
    return if drive_entries.size != 1

    child_file = drive_entries.first

    (drive_entry.file? && drive_entry.id == child_file.id) ||
      (drive_entry.folder? && child_file.descendant_of?(drive_entry))
  end

  def detect_content_type(attachment)
    content_type = attachment.content_type
    if content_type.blank? || content_type == 'application/octet-stream'
      content_type = Redmine::MimeType.of(attachment.filename)
    end
    content_type.to_s
  end

  def is_pdf?(attachment)
    Redmine::MimeType.of(attachment.filename) == 'application/pdf'
  end

  def retrieve_query(klass = DriveEntryQuery, use_session = true, options = {})
    session_key = klass.name.underscore.to_sym

    if params[:query_id].present?
      scope = klass.where(project_id: nil)
      scope = scope.or(klass.where(project_id: @project)) if @project
      @query = scope.find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[session_key] = { id: @query.id, project_id: @query.project_id } if use_session
    elsif api_request? || params[:set_filter] || !use_session || session[session_key].nil?
      # Give it a name, required to be valid
      @query = klass.new(name: '_', project: @project)
      @query.build_from_params(params)
      if use_session
        session[session_key] = {
          project_id: @query.project_id,
          filters: @query.filters,
          column_names: @query.column_names,
          sort: @query.sort_criteria.to_a
        }
      end
    else
      # retrieve from session
      @query = nil
      @query = klass.find_by_id(session[session_key][:id]) if session[session_key][:id]
      @query ||= klass.new(
        name: '_',
        filters: session[session_key][:filters],
        column_names: session[session_key][:column_names],
        sort_criteria: session[session_key][:sort]
      )
      @query.project = @project
    end

    @query
  end

  def drive_entries_by_session
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? @query.default_sort_criteria : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      @current_folder.children_by_query(@query, order: sort_clause, search: params[:search])
    end
  end

  def public_show
    if @drive_entry.folder?
      if @current_folder && !@current_folder.descendant_of?(@drive_entry)
        return render_403
      end

      @query = DriveEntryQuery.new(name: '_', project: @drive_entry.project)
      @drive_entries = @query.drive_entries(public: true, parent_id: @current_folder.try(:id) || @drive_entry.id)
    else
      redirect_to action: :download, ids: [@drive_entry.id],
                  id: @drive_entry, token: params[:token], timestamp: params[:timestamp]
    end
  end

  def issue_shared_files_warning
    if !params[:force_delete] && IssueDriveFile.where(drive_entry_id: @drive_entries.map(&:id)).present?
      render :force_delete_modal
    end
  end

  def new_name_copies(entry)
    @new_name_copies ||= DriveEntry.with_equal_name(entry).except(entry)
  end

  def rename_copies(copies)
    copies.all? { |copy| copy.update(name: @drive_entry.name) }
  end

  def remove_copies(copies)
    copies.all? { |copy| copy.destroy }
  end

  def increase_version(entry)
    entry.version = new_name_copies(entry).maximum(:version) + 1
  end

  def is_drive_entry?(drive_entries)
    drive_entries.all? { |drive_entry| drive_entry.is_a?(DriveEntry) }
  end

  def check_permission(drive_entries)
    drive_entries.any? { |drive_entry| User.current.allowed_to?(:edit_drive_entries, drive_entry.project, global: true) }
  end
end
