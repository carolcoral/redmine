# frozen_string_literal: true

# 会话 / Cookie 签名密钥（已脱敏）
#
# 取值优先级：
#   1. 环境变量 SECRET_KEY_BASE（生产 / 集群环境请务必显式设置，多实例需一致）
#   2. config/.secret_key_base（已 gitignore，首次运行时自动生成并复用）
#
# 放在独立文件里而不是写死在仓库中，避免密钥随代码外泄；
# 复用本地文件则保证同一台机器重启后不会让所有人掉登录。

key_path = Rails.root.join('config/.secret_key_base')

key = ENV['SECRET_KEY_BASE'].to_s
if key.empty?
  key =
    if File.exist?(key_path)
      File.read(key_path).strip
    else
      generated = SecureRandom.hex(64)
      File.write(key_path, generated)
      Rails.logger&.warn('[Redmine] 未设置 SECRET_KEY_BASE，已生成 config/.secret_key_base 并复用')
      generated
    end
end

RedmineApp::Application.config.secret_key_base = key
