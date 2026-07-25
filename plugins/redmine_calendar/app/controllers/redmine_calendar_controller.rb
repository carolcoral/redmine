class RedmineCalendarController < ApplicationController
  before_action :find_project
  before_action :find_issue, except: [:create_issue]
  before_action :authorize

  accept_api_auth :create_issue, :update_issue_date, :update_issue_assigned_to, :destroy_issue

  def create_issue
    @issue = Issue.new
    @issue.project = @project
    @issue.author = User.current
    @issue.start_date = params[:start_date]
    @issue.due_date = params[:due_date]
    @issue.tracker = @project.trackers.first
    
    if params[:tracker_id].present?
      @issue.tracker = Tracker.find_by(id: params[:tracker_id])
    end
    
    @issue.subject = params[:subject] || "新建问题 #{@issue.start_date}"
    @issue.priority = IssuePriority.default
    
    if params[:assigned_to_id].present?
      assigned_to = Principal.find_by(id: params[:assigned_to_id])
      @issue.assigned_to = assigned_to if assigned_to && @project.principals.include?(assigned_to)
    end

    if @issue.save
      @issue.create_journal(User.current)
      
      journal_details = []
      journal_details << JournalDetail.new(property: 'attr', prop_key: 'subject', value: @issue.subject)
      journal_details << JournalDetail.new(property: 'attr', prop_key: 'start_date', value: @issue.start_date.to_s)
      journal_details << JournalDetail.new(property: 'attr', prop_key: 'due_date', value: @issue.due_date.to_s) if @issue.due_date
      journal_details << JournalDetail.new(property: 'attr', prop_key: 'tracker_id', value: @issue.tracker_id.to_s)
      journal_details << JournalDetail.new(property: 'attr', prop_key: 'priority_id', value: @issue.priority_id.to_s)
      if @issue.assigned_to
        journal_details << JournalDetail.new(property: 'attr', prop_key: 'assigned_to_id', old_value: nil, value: @issue.assigned_to_id.to_s)
      end
      
      @issue.current_journal.details << journal_details
      @issue.current_journal.save
      
      render json: {
        success: true,
        issue: {
          id: @issue.id,
          subject: @issue.subject,
          start_date: @issue.start_date,
          due_date: @issue.due_date,
          tracker_name: @issue.tracker.name,
          status_name: @issue.status.name,
          assigned_to_id: @issue.assigned_to_id,
          assigned_to_name: @issue.assigned_to.try(:name),
          project_id: @issue.project_id
        }
      }
    else
      render json: { success: false, errors: @issue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_issue_date
    old_start_date = @issue.start_date
    old_due_date = @issue.due_date
    
    @issue.start_date = params[:start_date] if params[:start_date].present?
    @issue.due_date = params[:due_date] if params[:due_date].present?
    
    if @issue.save
      @issue.create_journal(User.current)
      
      journal_details = []
      if old_start_date != @issue.start_date
        journal_details << JournalDetail.new(
          property: 'attr', 
          prop_key: 'start_date', 
          old_value: old_start_date.to_s, 
          value: @issue.start_date.to_s
        )
      end
      if old_due_date != @issue.due_date
        journal_details << JournalDetail.new(
          property: 'attr', 
          prop_key: 'due_date', 
          old_value: old_due_date.to_s, 
          value: @issue.due_date.to_s
        )
      end
      
      @issue.current_journal.details << journal_details
      @issue.current_journal.save
      
      render json: {
        success: true,
        issue: {
          id: @issue.id,
          subject: @issue.subject,
          start_date: @issue.start_date,
          due_date: @issue.due_date,
          tracker_name: @issue.tracker.name,
          status_name: @issue.status.name,
          assigned_to_id: @issue.assigned_to_id,
          assigned_to_name: @issue.assigned_to.try(:name),
          project_id: @issue.project_id
        }
      }
    else
      render json: { success: false, errors: @issue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_issue_assigned_to
    old_assigned_to_id = @issue.assigned_to_id
    
    if params[:assigned_to_id].present?
      assigned_to = Principal.find_by(id: params[:assigned_to_id])
      if assigned_to && @project.principals.include?(assigned_to)
        @issue.assigned_to = assigned_to
      else
        render json: { success: false, error: 'Invalid assignee' }, status: :unprocessable_entity
        return
      end
    else
      @issue.assigned_to = nil
    end
    
    if @issue.save
      @issue.create_journal(User.current)
      
      journal_detail = JournalDetail.new(
        property: 'attr', 
        prop_key: 'assigned_to_id', 
        old_value: old_assigned_to_id.to_s, 
        value: @issue.assigned_to_id.to_s
      )
      
      @issue.current_journal.details << journal_detail
      @issue.current_journal.save
      
      render json: {
        success: true,
        issue: {
          id: @issue.id,
          subject: @issue.subject,
          start_date: @issue.start_date,
          due_date: @issue.due_date,
          tracker_name: @issue.tracker.name,
          status_name: @issue.status.name,
          assigned_to_id: @issue.assigned_to_id,
          assigned_to_name: @issue.assigned_to.try(:name),
          project_id: @issue.project_id
        }
      }
    else
      render json: { success: false, errors: @issue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_issue_created_on
    old_created_on = @issue.created_on
    
    begin
      # Parse the date
      new_created_on = params[:created_on].present? ? Date.parse(params[:created_on]) : nil
      
      if new_created_on.nil?
        render json: { success: false, error: 'Invalid date format' }, status: :unprocessable_entity
        return
      end
      
      # Update created_on - bypass validations for this specific field
      @issue.update_column(:created_on, new_created_on)
      
      # Create journal entry for the change
      @issue.init_journal(User.current)
      @issue.current_journal.details << JournalDetail.new(
        property: 'attr', 
        prop_key: 'created_on', 
        old_value: old_created_on.to_s, 
        value: new_created_on.to_s
      )
      @issue.current_journal.save
      
      render json: {
        success: true,
        issue: {
          id: @issue.id,
          subject: @issue.subject,
          created_on: @issue.created_on,
          project_id: @issue.project_id
        }
      }
    rescue ArgumentError => e
      render json: { success: false, error: 'Invalid date format: ' + e.message }, status: :unprocessable_entity
    rescue => e
      render json: { success: false, error: 'Failed to update created on date: ' + e.message }, status: :unprocessable_entity
    end
  end

  def destroy_issue
    if @issue.destroy
      render json: { success: true, message: 'Issue deleted successfully' }
    else
      render json: { success: false, error: 'Failed to delete issue' }, status: :unprocessable_entity
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  end

  def find_issue
    @issue = Issue.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Issue not found' }, status: :not_found
  end

  def authorize
    if @issue
      unless User.current.allowed_to?(:edit_calendar_issues, @project || @issue.project)
        deny_access
      end
    else
      unless User.current.allowed_to?(:edit_calendar_issues, @project)
        deny_access
      end
    end
  end

  def deny_access
    render json: { success: false, error: 'Access denied' }, status: :forbidden
  end
end