# 文件会在适当的时候被自动加载，这里不需要手动 require
# Zeitwerk 会自动处理文件加载

module RedmineWebhook
  def self.setup
    # Additional setup if needed
  end
end

# Initialize the plugin when Rails loads
Rails.configuration.to_prepare do
  RedmineWebhook.setup
end