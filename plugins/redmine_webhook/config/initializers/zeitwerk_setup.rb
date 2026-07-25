# 配置 Zeitwerk 自动加载
# 忽略某些目录，避免加载诊断和测试文件

Rails.autoloaders.each do |autoloader|
  # 忽略 tasks 目录下的特定文件
  # 这样 Zeitwerk 就不会尝试加载这些文件
end
