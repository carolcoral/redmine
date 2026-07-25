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

class ResourceQueriesController < ApplicationController
  menu_item :resources

  before_action :find_query, :except => [:new, :create]
  before_action :find_optional_project, :only => [:new, :create]

  include QueriesHelper
  helper :queries
  helper :resource_bookings

  def new
    @query = query_class.new
    @query.user = User.current
    @query.project = @project
    @query.visibility = ResourceQuery::VISIBILITY_PRIVATE unless User.current.allowed_to?(:manage_public_queries, @project) || User.current.admin?
    @query.build_from_params(params)
  end

  def create
    @query = query_class.new
    @query.user = User.current
    @query.project = params[:query_is_for_all] ? nil : @project
    @query.build_from_params(params)
    @query.draw_selected_columns = '1' if params[:c]
    @query.name = params[:query] && params[:query][:name]
    if User.current.allowed_to?(:manage_public_queries, @project) || User.current.admin?
      @query.visibility = (params[:query] && params[:query][:visibility]) || query_class::VISIBILITY_PRIVATE
      @query.role_ids = params[:query] && params[:query][:role_ids]
    else
      @query.visibility = query_class::VISIBILITY_PRIVATE
    end
    @query.column_names = nil if params[:default_columns]

    if @query.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to_resources(:query_id => @query)
    else
      render :action => 'new', :layout => !request.xhr?
    end
  end

  def edit
  end

  def update
    @query.project = nil if params[:query_is_for_all]
    @query.build_from_params(params)
    @query.name = params[:query] && params[:query][:name]
    @query.draw_selected_columns = params[:c] ? '1' : nil
    if User.current.allowed_to?(:manage_public_queries, @project) || User.current.admin?
      @query.visibility = (params[:query] && params[:query][:visibility]) || ResourceQuery::VISIBILITY_PRIVATE
      @query.role_ids = params[:query] && params[:query][:role_ids]
    else
      @query.visibility = ResourceQuery::VISIBILITY_PRIVATE
    end
    @query.column_names = nil if params[:default_columns]

    if @query.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to_resources(:query_id => @query)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @query.destroy
    redirect_to_resources(:set_filter => 1)
  end

  private
  def find_query
    @query = ResourceBookingQuery.find_by_id(params[:id]) || ResourceIssuesQuery.find_by_id(params[:id])
    @project = @query.project
    render_403 unless @query.editable_by?(User.current)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_optional_project
    @project = Project.find(params[:project_id]) if params[:project_id]
    render_403 unless User.current.allowed_to?(:add_agile_queries, @project, :global => true)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def redirect_to_resources(options)
    if @project
      redirect_to redirect_path(options.merge(:project_id => @project))
    else
      redirect_to redirect_path(options)
    end
  end

  def query_class
    (params[:object_type] == ResourceIssuesQuery.name || params[:chart_type] == 'issues_chart') ? ResourceIssuesQuery : ResourceBookingQuery
  end

  def redirect_path(options)
    @query.is_a?(ResourceIssuesQuery) ? resource_issues_path(options) : resource_bookings_path(options)
  end
end
