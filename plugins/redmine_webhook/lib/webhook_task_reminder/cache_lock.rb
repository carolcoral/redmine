module WebhookTaskReminder
  class CacheLock
    def initialize(cache: Rails.cache, logger: Rails.logger)
      @cache = cache
      @logger = logger
    end

    # 获取分布式锁，用于多机部署环境
    # 依赖支持 unless_exist 的 cache store（RedisCacheStore/MemCacheStore）。
    # 如果不支持，会回退到非严格原子方式（仍尽量避免重复执行）。
    def acquire(key, ttl:)
      value = "#{Process.pid}-#{Thread.current.object_id}-#{Time.now.to_f}"

      if supports_unless_exist?
        # 使用 Redis SETNX 或 MemCache add 原子操作
        result = @cache.write(key, value, expires_in: ttl, unless_exist: true)
        if result
          @logger.info "[CacheLock] Acquired lock: #{key}"
          return value
        else
          @logger.info "[CacheLock] Lock already exists: #{key}"
          return nil
        end
      end

      # fallback：不是严格原子，适用于 MemoryStore（单进程）或低并发场景
      return nil if @cache.exist?(key)
      @cache.write(key, value, expires_in: ttl)
      @logger.warn "[CacheLock] Acquired fallback lock (not atomic): #{key}"
      value
    rescue StandardError => e
      @logger.error "[CacheLock] Failed to acquire lock: #{key}, error: #{e.message}"
      nil
    end

    # 释放锁（可选，当前实现通过 TTL 自动释放）
    def release(key, value)
      # 只有锁的持有者才能释放（CAS 机制）
      if @cache.read(key) == value
        @cache.delete(key)
        @logger.info "[CacheLock] Released lock: #{key}"
      end
    rescue StandardError => e
      @logger.error "[CacheLock] Failed to release lock: #{key}, error: #{e.message}"
    end

    private

    def supports_unless_exist?
      @supports_unless_exist ||= begin
        # Rails cache store 的 write 支持 unless_exist 时不会抛错，但不同 store 行为不同；
        # 用一次探测写入来判断（使用极短 TTL 且随机 key）。
        probe_key = "redmine_webhook:lock_probe:#{SecureRandom.hex(8)}"
        ok = @cache.write(probe_key, '1', expires_in: 1.second, unless_exist: true)
        @cache.delete(probe_key) rescue nil
        result = ok == true || ok == false
        @logger.info "[CacheLock] Cache store supports unless_exist: #{result}, class: #{@cache.class.name}"
        result
      rescue StandardError => e
        @logger.warn "[CacheLock] Failed to detect unless_exist support: #{e.message}"
        false
      end
    end
  end
end

