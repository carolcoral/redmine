# 快速安装指南

## 安装步骤

### 方法1：使用插件目录

```bash
# 进入 Redmine 插件目录
cd /path/to/redmine/plugins

# 克隆插件（确保目录名为 redmine_calendar）
git clone <repository-url> redmine_calendar

# 返回 Redmine 根目录
cd /path/to/redmine

# 安装依赖
bundle install

# 重启 Redmine
touch tmp/restart.txt  # 如果使用 Passenger
```

### 方法2：手动复制

```bash
# 将插件文件复制到 Redmine 插件目录
cp -r redmine_calendar /path/to/redmine/plugins/

# 确保目录名正确
mv /path/to/redmine/plugins/redmine_calendar-<version> /path/to/redmine/plugins/redmine_calendar

# 安装依赖并重启
cd /path/to/redmine
bundle install
touch tmp/restart.txt
```

## 配置权限

1. 以管理员身份登录 Redmine
2. 进入 管理 -> 角色和权限
3. 选择需要授权的角色
4. 在项目权限中找到 日历 -> 编辑日历问题
5. 勾选并保存

## 验证安装

1. 进入任意项目的日历视图
2. 尝试双击日期（应弹出创建问题对话框）
3. 尝试拖拽问题（应能移动到其他日期）
4. 右键点击问题（应显示上下文菜单）

## 故障排除

### 问题1：插件无法加载

**现象**：Redmine 启动时报错 `cannot load such file`

**解决**：
- 确保插件目录名为 `redmine_calendar`
- 检查文件权限是否正确
- 查看 `init.rb` 中的加载路径

### 问题2：JavaScript 不生效

**现象**：双击、拖拽等功能无响应

**解决**：
- 清除浏览器缓存
- 检查浏览器控制台是否有 JavaScript 错误
- 确认插件资源文件已正确加载

### 问题3：权限问题

**现象**：操作时报"访问被拒绝"

**解决**：
- 检查用户角色是否有"编辑日历问题"权限
- 确认用户在项目中是成员

### 问题4：路由错误

**现象**：AJAX 请求返回 404

**解决**：
- 重启 Redmine 确保路由加载
- 检查 `config/routes.rb` 配置
- 查看 `log/production.log` 中的错误详情

## 卸载插件

```bash
cd /path/to/redmine

# 如果有数据库迁移需要回滚
# bundle exec rake redmine:plugins:migrate NAME=redmine_calendar VERSION=0 RAILS_ENV=production

# 删除插件目录
rm -rf plugins/redmine_calendar

# 重启 Redmine
touch tmp/restart.txt
```

## 日志查看

如果遇到问题，请查看日志文件：

```bash
# 生产环境日志
tail -f log/production.log

# 开发环境日志
tail -f log/development.log
```

## 获取帮助

- 查看插件文档：README.md
- 提交 Issue：GitHub Issues
- 查看 Redmine 日志获取详细错误信息