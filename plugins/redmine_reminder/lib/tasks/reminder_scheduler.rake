require_relative '../redmine_reminder/scheduler'

namespace :redmine_reminder do
  desc 'Send reminder emails for upcoming and overdue tasks'
  task send_reminders: :environment do
    puts "Starting reminder task..."
    scheduler = RedmineReminder::Scheduler.new
    scheduler.run
    puts "Reminder task completed."
  end

  desc 'Send reminder emails (alias task)'
  task :reminder => 'send_reminders'
end

