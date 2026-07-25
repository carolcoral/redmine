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

class ResourceBookingsController < ApplicationController
  menu_item :resources

  before_action :require_login, :find_project_by_project_id, :find_user_by_user_id, only: :issues_autocomplete
  before_action :find_optional_project, except: :issues_autocomplete
  before_action :find_resource_booking, only: [:destroy, :split, :show]
  before_action :build_resource_booking_from_params, only: [:new, :create, :edit, :update]
  before_action :collect_work_data, only: [:new, :edit]
  before_action :set_user_blocks_to_update, only: [:new, :create, :update, :destroy, :split]

  accept_api_auth :index, :show, :create, :update, :destroy

  helper :issues
  helper :queries
  include ResourceBookingsHelper
  include QueriesHelper
  include Redmine::Utils::DateCalculation

  def index
    retrieve_query

    if @query.valid?
      respond_to do |format|
        format.html do
          @rb_chart = @query.chart_class.new(@project, @query, params)
        end
        format.api do
          if User.current.allowed_to?(:view_resources, nil, :global => true)
            @resources = ResourceBooking.visible
            @resource_count = @resources.count
          end
        end
      end
    end
  end

  def new
  end

  def create
    if @resource_booking.save
      respond_to do |format|
        format.js do
          add_to_flash_resource_booking_warnings
          render_update_chart l(:notice_successful_create)
        end
        format.api do
          render :action => 'show', :status => :created
        end
      end
    else
      respond_to do |format|
        format.js do
          collect_work_data
          render :new
        end
        format.api do
          render_validation_errors(@resource_booking)
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.api do
        @resource_booking
      end
    end
  end

  def edit
    # Run validations (There is no method "validate" in Rails 3)
    @resource_booking.valid?
  end

  def update
    if @resource_booking.save
      respond_to do |format|
        format.js do
          add_to_flash_resource_booking_warnings
          render_update_chart l(:notice_successful_update)
        end
        format.api do
          render_api_ok
        end
      end
    else
      respond_to do |format|
        format.js do
          collect_work_data
          render :edit
        end
        format.api do
          render_validation_errors(@resource_booking)
        end
      end
    end
  end

  def destroy
    if @resource_booking.destroy
      respond_to do |format|
        format.js do
          render_update_chart l(:notice_successful_delete)
        end
        format.api do
          render_api_ok
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:error] = l(:notice_could_not_delete)
          render partial: 'update_chart'
        end
        format.api do
          render_api_ok
        end
      end
    end
  end

  def split
    split_date = @resource_booking.start_date + params[:split_offset].to_i.days
    new_resource_booking = @resource_booking.dup
    @resource_booking.end_date = split_date - 1.day
    new_resource_booking.start_date = split_date

    ResourceBooking.transaction do
      if @resource_booking.save && new_resource_booking.save
        render_update_chart l(:notice_successful_create)
      else
        flash.now[:error] = l(:error_save_failed)
        render partial: 'update_chart'
        raise ActiveRecord::Rollback
      end
    end
  end

  def issues_autocomplete
    @issues = []
    q = (params[:q] || params[:term]).to_s.strip
    scope = Issue
    scope = scope.includes(:tracker).where(project_id: @project.id) if @project.present?

    if q.present?
      if q.match(/\A#?(\d+)\z/)
        @issues << scope.find_by_id($1.to_i)
      end
    end

    scope = scope.like(q).select_with_sorting_by_groups(@user.id)
    @issues += scope.limit(Issue::SELECT2_ISSUES_LIMIT).to_a
    @issues.compact!

    render json: Issue.build_issues_select2_data(@issues, @user)
  end

  private

  def add_to_flash_resource_booking_warnings
    if @resource_booking.warnings.present?
      flash.now[:warning] = @resource_booking.warnings.full_messages.join('; ')
    end
  end

  def render_update_chart(notice)
    if @user_blocks
      flash.now[:notice] = notice
      render partial: 'update_chart', locals: { resize: true }
    else
      flash[:notice] = notice
      render js: "window.location = '#{bookings_index_path}'"
    end
  end

  def set_user_blocks_to_update
    retrieve_query
    @query.add_filter('assigned_to_id', '=', [@resource_booking.assigned_to_id.to_s])
    return unless @query.valid?

    @user_blocks = { @resource_booking.assigned_to_id => RedmineResources::Charts::AllocationChart.new(@project, @query) }

    assigned_to_id_was = @resource_booking.assigned_to_id_was
    if assigned_to_id_was && (@resource_booking.assigned_to_id != assigned_to_id_was)
      query = @query.dup
      query.add_filter('assigned_to_id', '=', [assigned_to_id_was.to_s])
      @user_blocks[assigned_to_id_was] = RedmineResources::Charts::AllocationChart.new(@project, query)
    end
  end

  def find_resource_booking
    @resource_booking = ResourceBooking.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def build_resource_booking_from_params
    if params[:id].blank?
      @resource_booking = ResourceBooking.new(project: @project, author: User.current)
    else
      return unless find_resource_booking
    end

    @resource_booking.safe_attributes = params[:resource_booking]

    if params[:zoom] && params[:zoom].to_i == 1 # monthly scale
      @resource_booking.start_date += params[:start_date_offset].to_i.months if params[:start_date_offset]
      @resource_booking.end_date = @resource_booking.get_end_date + params[:end_date_offset].to_i.months if params[:end_date_offset]
      @resource_booking.end_date = @resource_booking.end_date.end_of_month if @resource_booking.new_record?
    elsif params[:zoom] && params[:zoom].to_i == 2 # weekly scale
      @resource_booking.start_date += params[:start_date_offset].to_i.weeks if params[:start_date_offset]
      @resource_booking.end_date = @resource_booking.get_end_date + params[:end_date_offset].to_i.weeks if params[:end_date_offset]
      @resource_booking.end_date = @resource_booking.end_date.end_of_week if @resource_booking.new_record?
    else # daily scale
      @resource_booking.start_date += params[:start_date_offset].to_i.days if params[:start_date_offset]
      @resource_booking.end_date = @resource_booking.get_end_date + params[:end_date_offset].to_i.days if params[:end_date_offset]
    end
  end

  # Retrieve query from session or build a new query
  def retrieve_query
    session_key = :resource_booking_query
    if params[:query_id].present?
      cond = 'project_id IS NULL'
      cond << " OR project_id = #{@project.id}" if @project
      @query = ResourceBookingQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[session_key][:options][:date_from] = params[:date_from].to_date if params[:date_from]
      @query.date_from = session[session_key][:options][:date_from]
    elsif params[:set_filter] || session[session_key].nil? || session[session_key][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = ResourceBookingQuery.new(name: '_', project: @project)
      @query.build_from_params(params)
      session[session_key] = { project_id: @query.project_id, group_by: @query.group_by, filters: @query.filters, options: @query.options, column_names: @query.column_names }
    else
      # retrieve from session
      session[session_key][:options][:date_from] = params[:date_from].to_date if params[:date_from]
      session[session_key][:options][:date_from] = "#{params[:year]}-#{params[:month]}-01".to_date if (params[:year] && params[:month])
      @query = ResourceBookingQuery.new(name: '_', group_by: session[session_key][:group_by], filters: session[session_key][:filters], options: session[session_key][:options], column_names: session[session_key][:column_names])
      @query.project = @project
    end
    @query
  end

  def find_user_by_user_id
    @user = User.find(params[:user_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def collect_work_data
    @issue = @resource_booking.issue
    @projects = ResourceBooking.allowed_projects
    @resource_booking_project = @resource_booking.project || @projects.first

    users = @resource_booking_project.users
    selected_user = users.find_by(id: @resource_booking.assigned_to_id) || users.first
    @person = RedmineResources.people_pro_plugin_installed? && selected_user && selected_user.becomes(Person)

    @user_workday_length = @person.try(:workday_length) || RedmineResources.default_workday_length
    @resource_booking.assigned_to = selected_user
  end
end
