require 'concurrent'

module WebhookTaskReminder
  class Scheduler
    class << self
      def start!
        return if started?

        @started = true
        @task = Concurrent::TimerTask.new(execution_interval: 30, timeout_interval: 25) do
          Runner.new.tick
        end
        @task.execute
        Rails.logger.info "[WebhookTaskReminder] scheduler started"
      rescue StandardError => e
        @started = false
        Rails.logger.error "[WebhookTaskReminder] scheduler start failed: #{e.class}:#{e.message}"
      end

      def started?
        @started == true
      end
    end
  end
end

