module WebhookTaskReminder
  # 基于数据库的锁实现，适用于容器化部署环境
  # 当缓存不支持分布式锁时，使用数据库作为锁后端
  class DatabaseLock
    # 创建锁表（如果不存在）
    def self.create_lock_table
      ActiveRecord::Base.connection.create_table :webhook_locks, force: false do |t|
        t.string :key, null: false
        t.string :value, null: false
        t.timestamp :expires_at, null: false
        t.timestamps
      end

      # 添加索引
      ActiveRecord::Base.connection.add_index :webhook_locks, :key, unique: true, name: 'index_webhook_locks_on_key' unless
        ActiveRecord::Base.connection.index_exists?(:webhook_locks, :key)
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn "[DatabaseLock] Failed to create lock table: #{e.message}"
    end

    def initialize(logger: Rails.logger)
      @logger = logger
      ensure_lock_table_exists
    end

    # 获取锁
    def acquire(key, ttl:)
      value = "#{hostname}-#{Process.pid}-#{Thread.current.object_id}-#{Time.now.to_f}"
      expires_at = Time.now + ttl.seconds

      begin
        # 尝试插入锁记录
        lock = WebhookLock.new(
          key: key,
          value: value,
          expires_at: expires_at
        )

        if lock.save
          @logger.info "[DatabaseLock] Acquired lock: #{key}"
          return value
        else
          @logger.info "[DatabaseLock] Failed to acquire lock (save failed): #{key}"
          return nil
        end
      rescue ActiveRecord::RecordNotUnique
        # 锁已存在，检查是否过期
        @logger.info "[DatabaseLock] Lock already exists: #{key}"

        existing_lock = WebhookLock.where(key: key).first
        if existing_lock && existing_lock.expires_at < Time.now
          # 锁已过期，删除并重新获取
          @logger.info "[DatabaseLock] Lock expired, releasing: #{key}"
          existing_lock.destroy

          # 重新尝试获取
          lock = WebhookLock.new(
            key: key,
            value: value,
            expires_at: expires_at
          )
          if lock.save
            @logger.info "[DatabaseLock] Acquired lock (after cleanup): #{key}"
            return value
          end
        end

        return nil
      rescue StandardError => e
        @logger.error "[DatabaseLock] Failed to acquire lock: #{key}, error: #{e.message}"
        return nil
      end
    end

    # 释放锁
    def release(key, value)
      lock = WebhookLock.where(key: key, value: value).first
      if lock
        lock.destroy
        @logger.info "[DatabaseLock] Released lock: #{key}"
      else
        @logger.warn "[DatabaseLock] Failed to release lock (not found or not owner): #{key}"
      end
    rescue StandardError => e
      @logger.error "[DatabaseLock] Failed to release lock: #{key}, error: #{e.message}"
    end

    # 清理过期锁
    def self.cleanup_expired_locks
      deleted = WebhookLock.where('expires_at < ?', Time.now).delete_all
      Rails.logger.info "[DatabaseLock] Cleaned up #{deleted} expired locks"
      deleted
    rescue StandardError => e
      Rails.logger.error "[DatabaseLock] Failed to cleanup expired locks: #{e.message}"
      0
    end

    private

    def ensure_lock_table_exists
      return if WebhookLock.table_exists?

      @logger.info "[DatabaseLock] Creating lock table..."
      self.class.create_lock_table
      @logger.info "[DatabaseLock] Lock table created successfully"
    end

    def hostname
      @hostname ||= Socket.gethostname rescue 'unknown'
    end
  end

  # 锁记录模型
  class WebhookLock < ActiveRecord::Base
    self.table_name = 'webhook_locks'
  end
end
