Rails.application.routes.draw do
  post 'redmine_calendar/create_issue', to: 'redmine_calendar#create_issue'
  put 'redmine_calendar/update_issue_date/:id', to: 'redmine_calendar#update_issue_date'
  put 'redmine_calendar/update_issue_assigned_to/:id', to: 'redmine_calendar#update_issue_assigned_to'
  put 'redmine_calendar/update_issue_created_on/:id', to: 'redmine_calendar#update_issue_created_on'
  delete 'redmine_calendar/destroy_issue/:id', to: 'redmine_calendar#destroy_issue'
end