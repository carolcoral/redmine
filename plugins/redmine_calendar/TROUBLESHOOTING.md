# 日历模块不显示 - 故障排查指南

## 问题现象
项目配置中启用了"日历"，但日历菜单不显示

## 排查步骤

### 1. 检查 Redmine 内置日历功能

Redmine 6.1 自带日历功能，请确认：

- 进入 **管理 → 角色和权限**
- 选择你的角色
- 在"项目"权限中检查是否有"查看日历"权限
- 确保该权限已勾选

### 2. 检查项目模块设置

- 进入项目设置页面
- 点击"模块"标签
- 确保"日历"模块已启用（打勾）
- 保存设置

### 3. 验证用户权限

- 你是项目成员吗？
- 你的角色有"查看日历"权限吗？
- 尝试用管理员账号查看是否显示

### 4. 检查插件是否加载成功

在 Redmine 根目录运行：

```bash
# 检查插件是否被识别
bundle exec rake redmine:plugins RAILS_ENV=production

# 查看插件列表
cat log/production.log | grep -i "calendar"
```

### 5. 检查菜单显示

登录 Redmine 控制台检查：

```bash
bundle exec rails console -e production
```

然后执行：

```ruby
# 检查日历菜单是否存在
Redmine::MenuManager.items(:project_menu).each { |item| puts "#{item.name}: #{item.url}" }

# 检查是否有日历菜单
puts "Calendar menu exists: #{Redmine::MenuManager.items(:project_menu).find(:calendar).present?}"
```

### 6. 检查插件钩子是否生效

```bash
bundle exec rails console -e production
```

```ruby
# 检查钩子是否注册
puts "Hooks registered: #{Redmine::Hook.hook_listeners[:view_layouts_base_html_head].any? { |l| l.to_s.include?('RedmineCalendar') } }"
```

## 常见问题

### 问题1：内置日历被禁用

**解决方案**：
1. 进入 管理 → 设置 → 项目
2. 检查"默认启用的新项目模块"是否包含日历
3. 如果不包含，手动在项目中启用

### 问题2：权限问题

**解决方案**：
1. 进入 管理 → 角色和权限
2. 确保角色有"查看日历"权限
3. 重新登录或清除权限缓存

### 问题3：项目模块未启用

**解决方案**：
1. 进入项目设置
2. 点击"模块"标签
3. 勾选"日历"并保存

### 问题4：缓存问题

**解决方案**：
```bash
# 清除 Redmine 缓存
cd /path/to/redmine
bundle exec rake tmp:cache:clear RAILS_ENV=production

# 重启 Redmine
touch tmp/restart.txt
```

## 验证修复

修复后，日历菜单应显示在：

**项目菜单** → 活动 → **日历**

如果还是不显示，请检查：

1. **URL 直接访问**：访问 `/projects/项目标识/activity/calendar`
2. **错误日志**：查看 `log/production.log` 中的错误
3. **浏览器控制台**：检查是否有 JavaScript 错误

## 插件功能说明

本插件**不是替换** Redmine 内置日历，而是**增强**它：

- ✅ 保持 Redmine 内置日历功能不变
- ✅ 添加双击创建问题功能
- ✅ 添加拖拽修改日期功能
- ✅ 添加右键菜单功能
- ✅ 所有增强都在现有日历页面上生效

## 快速验证

如果以上步骤都无效，尝试禁用本插件：

```bash
# 临时重命名插件目录
cd /path/to/redmine/plugins
mv redmine_calendar redmine_calendar.disabled

# 重启 Redmine
touch tmp/restart.txt
```

然后检查内置日历是否正常显示：

- 如果显示 → 插件可能与其他插件冲突
- 如果不显示 → Redmine 本身配置问题

## 获取帮助

如果问题仍然存在：

1. 提供 Redmine 版本信息
2. 提供错误日志（`log/production.log`）
3. 提供角色权限截图
4. 提供项目模块设置截图
5. 在 GitHub 提交 Issue