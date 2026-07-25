namespace :webhook do
  desc '检查缓存配置和锁机制'
  task check_cache: :environment do
    puts '=== 缓存配置检查 ==='
    puts

    # 1. 检查缓存存储类型
    cache_store = Rails.cache
    puts "缓存存储类型: #{cache_store.class.name}"
    puts "缓存配置: #{Rails.application.config.cache_store.inspect}"
    puts

    # 2. 检查是否支持分布式锁
    lock = WebhookTaskReminder::CacheLock.new
    probe_key = "redmine_webhook:test_lock:#{SecureRandom.uuid}"

    result = cache_store.write(probe_key, 'test', expires_in: 5, unless_exist: true)
    if result == true
      puts "✓ 缓存存储支持 unless_exist (支持分布式锁)"
      use_cache_lock = true
    elsif result == false
      puts "✓ 缓存存储支持 unless_exist (支持分布式锁)，但key已存在"
      use_cache_lock = true
    else
      puts "✗ 缓存存储不支持 unless_exist (不支持分布式锁)"
      use_cache_lock = false
    end

    cache_store.delete(probe_key) rescue nil
    puts

    # 3. 检查数据库锁表
    if ActiveRecord::Base.connection.table_exists?(:webhook_locks)
      puts "✓ 数据库锁表已存在"
    else
      puts "✗ 数据库锁表不存在"
      puts "  注意：如果缓存不支持分布式锁，需要创建数据库锁表"
      puts "  运行: rake webhook:create_lock_table RAILS_ENV=production"
    end
    puts

    # 4. 检查将要使用的锁后端
    if use_cache_lock
      puts "推荐锁后端: 缓存锁 (CacheLock)"
      puts "  ✓ 适用于多机部署，前提是所有实例连接到同一个缓存服务器"
    else
      puts "推荐锁后端: 数据库锁 (DatabaseLock)"
      puts "  ✓ 适用于多机部署，前提是所有实例连接到同一个数据库"
      puts "  ✓ 基于数据库唯一索引实现分布式锁"
    end
    puts

    # 5. 测试锁的原子性
    puts '=== 测试锁的原子性 (并发测试) ==='
    test_key = "redmine_webhook:test_lock:#{SecureRandom.uuid}"

    thread1 = Thread.new do
      token1 = lock.acquire(test_key, ttl: 10)
      if token1
        puts "  线程1: 获取锁成功, token=#{token1}"
        sleep 2
        puts "  线程1: 释放锁"
        cache_store.delete(test_key)
      else
        puts "  线程1: 获取锁失败 (被其他线程占用)"
      end
    end

    thread2 = Thread.new do
      sleep 0.5  # 稍微延迟，模拟并发
      token2 = lock.acquire(test_key, ttl: 10)
      if token2
        puts "  线程2: 获取锁成功, token=#{token2}"
        sleep 1
        puts "  线程2: 释放锁"
        cache_store.delete(test_key)
      else
        puts "  线程2: 获取锁失败 (被其他线程占用) ✓ 正确行为"
      end
    end

    thread1.join
    thread2.join

    cache_store.delete(test_key) rescue nil
    puts

    # 6. 检查建议
    puts '=== 配置建议 ==='

    case cache_store.class.name
    when 'ActiveSupport::Cache::RedisCacheStore'
      puts '✓ 使用 Redis 缓存，支持分布式锁，适合多机部署'
      puts '  建议配置: config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }'
    when 'ActiveSupport::Cache::MemCacheStore'
      puts '✓ 使用 Memcached 缓存，支持分布式锁，适合多机部署'
      puts '  建议配置: config.cache_store = :mem_cache_store, "memcached1", "memcached2"'
    when 'ActiveSupport::Cache::FileStore'
      puts '⚠ 使用文件缓存，不支持分布式锁'
      puts '  不建议在多机部署环境中使用！'
      puts '  建议：'
      puts '    1. 切换到 Redis 或 Memcached（推荐）'
      puts '    2. 或者使用数据库锁（已自动启用）'
    when 'ActiveSupport::Cache::MemoryStore'
      puts '⚠ 使用内存缓存，不支持分布式锁'
      puts '  不建议在多机部署环境中使用！'
      puts '  建议：'
      puts '    1. 切换到 Redis 或 Memcached（推荐）'
      puts '    2. 或者使用数据库锁（已自动启用）'
    else
      puts "? 未知的缓存存储类型: #{cache_store.class.name}"
      puts '  请检查是否支持 unless_exist 参数'
    end
    puts

    # 7. 检查多机部署的注意事项
    puts '=== 多机部署注意事项 ==='
    puts '1. 确保所有实例连接到同一个数据库'
    puts '2. 确保所有实例连接到同一个缓存服务器（如果使用缓存锁）'
    puts '3. Redis URL: ENV["REDIS_URL"] 或 config/database.yml'
    puts '4. 缓存命名空间必须一致（默认: redmine_webhook）'
    puts '5. 检查日志中的锁信息确认锁是否正常工作：'
    puts '   - 使用缓存锁：[CacheLock] Acquired lock / Lock already exists'
    puts '   - 使用数据库锁：[DatabaseLock] Acquired lock / Failed to acquire lock'
    puts '6. 定期清理过期的锁：'
    puts '   rake webhook:cleanup_expired_locks RAILS_ENV=production'
    puts

    # 8. 容器化部署特别说明
    if File.exist?('/.dockerenv') || ENV['KUBERNETES_SERVICE_HOST']
      puts '=== 容器化部署特别说明 ==='
      puts '✓ 检测到容器化部署环境'
      puts
      puts '推荐配置：'
      puts '1. 使用数据库锁（DatabaseLock）- 推荐'
      puts '   - 优点：所有容器共享同一个数据库，天然支持分布式锁'
      puts '   - 缺点：需要额外的数据库表'
      puts '   - 配置：自动启用，无需额外配置'
      puts
      puts '2. 使用外部 Redis 缓存'
      puts '   - 优点：性能更好，支持更多功能'
      puts '   - 缺点：需要额外的 Redis 服务'
      puts '   - 配置：REDIS_URL=redis://redis-server:6379/2'
      puts
      puts '3. 不使用容器内的文件或内存缓存'
      puts '   - 每个容器有自己的文件系统和内存'
      puts '   - 无法实现跨容器的锁机制'
      puts
    end
  end

  desc '创建数据库锁表'
  task create_lock_table: :environment do
    puts '=== 创建数据库锁表 ==='
    WebhookTaskReminder::DatabaseLock.create_lock_table
    puts '✓ 数据库锁表创建完成'
  end

  desc '清理过期的锁'
  task cleanup_expired_locks: :environment do
    puts '=== 清理过期的锁 ==='
    count = WebhookTaskReminder::DatabaseLock.cleanup_expired_locks
    puts "✓ 已清理 #{count} 个过期锁"
  end

  desc '清理任务提醒缓存锁'
  task clear_cache_locks: :environment do
    puts '=== 清理任务提醒缓存锁 ==='

    unless Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore) ||
           Rails.cache.is_a?(ActiveSupport::Cache::MemCacheStore)
      puts '警告: 当前缓存存储不支持扫描操作，无法清理锁'
      exit
    end

    puts '正在清理任务提醒锁...'

    # Redis 特定实现
    if Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
      redis = Rails.cache.redis
      keys = redis.keys("redmine_webhook:task_reminder:sent:*")
      if keys.any?
        deleted = redis.del(keys)
        puts "✓ 已清理 #{deleted} 个缓存锁"
        puts "  锁的 key: #{keys.inspect}"
      else
        puts "没有找到任务提醒缓存锁"
      end
    else
      puts '当前缓存存储不支持批量清理锁'
    end
  end
end
