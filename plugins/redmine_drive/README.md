# Redmine Drive Plugin

## 插件介绍

Redmine Drive 是一个功能强大的文件存储插件，允许您在 Redmine 中存储、共享和从任何设备访问您的文件。它提供了类似云盘的文件管理功能，支持文件夹结构、文件版本控制、权限管理等特性。

### 主要功能

- 📁 **文件存储与管理**：在 Redmine 中集中存储和管理项目文件
- 📂 **文件夹结构**：支持创建多层文件夹结构，便于文件分类
- 👥 **文件共享**：在团队成员之间轻松共享文件
- 🔒 **权限控制**：基于 Redmine 权限系统的精细访问控制
- 🔄 **版本管理**：支持文件版本上传和历史版本查看
- 💬 **文件评论**：对文件进行评论和讨论
- 📱 **跨设备访问**：从任何设备访问您的文件
- 🔍 **全文搜索**：快速查找所需文件

## 系统要求

### Redmine 版本
- **最低版本**：Redmine 4.0 或更高版本
- **推荐版本**：Redmine 5.0+

### Ruby 版本
- **最低版本**：Ruby 2.5+
- **推荐版本**：Ruby 2.7+ 或 Ruby 3.0+

### Rails 版本
- **支持的 Rails 版本**：Rails 5.2+（取决于 Redmine 版本）

### 依赖 gem
- **redmineup**：>= 1.0.10

## 安装步骤

1. **下载插件**
   ```bash
   cd {REDMINE_ROOT}/plugins
   git clone https://github.com/your-repo/redmine_drive.git
   ```

2. **安装依赖**
   ```bash
   cd {REDMINE_ROOT}
   bundle install
   ```

3. **执行数据库迁移**
   ```bash
   bundle exec rake redmine:plugins:migrate NAME=redmine_drive RAILS_ENV=production
   ```

4. **重启 Redmine**
   - 如果使用 Passenger，重启 Apache/Nginx
   - 如果使用其他应用服务器，重启相应服务

5. **配置插件**
   - 登录 Redmine 管理员账户
   - 进入 管理 → 插件
   - 找到 Redmine Drive 插件，点击配置
   - 根据需要调整设置

## 升级步骤

1. **备份数据**
   ```bash
   # 备份数据库
   mysqldump -u username -p redmine_database > redmine_backup.sql
   ```

2. **更新插件代码**
   ```bash
   cd {REDMINE_ROOT}/plugins/redmine_drive
   git pull origin main
   ```

3. **更新依赖**
   ```bash
   cd {REDMINE_ROOT}
   bundle update redmineup
   ```

4. **执行数据库迁移**
   ```bash
   bundle exec rake redmine:plugins:migrate NAME=redmine_drive RAILS_ENV=production
   ```

5. **重启 Redmine**

## 插件配置

### 全局设置

在 Redmine 管理后台的插件配置页面，您可以设置：

- **在顶部菜单显示**：是否在 Redmine 顶部导航菜单显示 Drive 链接
- **存储路径**：文件存储的根目录路径
- **最大文件大小**：允许上传的最大文件大小
- **允许的文件类型**：允许上传的文件扩展名列表

### 项目权限

在项目设置中，您可以为不同角色分配以下权限：

- **查看文件**：查看和下载文件
- **添加文件**：上传新文件和创建文件夹
- **编辑文件**：编辑、删除、移动文件和文件夹
- **评论文件**：对文件发表评论

## 使用方法

### 访问 Drive

- **全局 Drive**：点击顶部菜单的 "Drive" 链接访问所有项目的文件
- **项目 Drive**：在项目菜单中点击 "Drive" 访问特定项目的文件

### 基本操作

1. **创建文件夹**：点击 "新建文件夹" 按钮
2. **上传文件**：点击 "上传文件" 按钮或拖拽文件到上传区域
3. **文件操作**：右键点击文件或文件夹进行操作（重命名、移动、删除、分享等）
4. **下载文件**：点击文件名直接下载
5. **版本管理**：在文件详情页可以查看历史版本并上传新版本

## 开发信息

### 插件信息

- **版本**：1.2.3（Light version）
- **作者**：RedmineUP
- **许可证**：GNU General Public License v3 (GPL-3.0)
- **项目主页**：http://redmineup.com/pages/plugins/drive
- **支持邮箱**：support@redmineup.com

### 兼容性

- ✅ Redmine 4.0.x
- ✅ Redmine 4.1.x
- ✅ Redmine 4.2.x
- ✅ Redmine 5.0.x
- ✅ Redmine 5.1.x

### 已知问题与限制

- Light 版本可能有功能限制，具体请参考官方文档
- 需要确保 `tmp/cache` 目录有正确的写入权限
- 大文件上传可能需要调整 Web 服务器的超时设置

## 故障排除

### 常见问题

**1. 插件安装后无法访问**
- 检查文件权限：`chmod -R 755 plugins/redmine_drive`
- 检查日志文件：`{REDMINE_ROOT}/log/production.log`

**2. 文件上传失败**
- 检查磁盘空间是否充足
- 检查上传文件大小是否超过限制
- 检查 `public/plugin_assets/redmine_drive` 目录权限

**3. 与看板插件冲突**
- 确保使用最新版本的插件
- 检查钩子（hook）调用顺序

### 日志文件

- Redmine 日志：`{REDMINE_ROOT}/log/production.log`
- Web 服务器日志：根据您的服务器配置查看相应日志

## 支持与贡献

- **官方支持**：support@redmineup.com
- **问题反馈**：请在 GitHub Issues 提交问题
- **功能建议**：欢迎提交 Pull Request 或功能建议

## 许可证

Copyright (C) 2011-2025 RedmineUP

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

## 致谢

感谢所有为 Redmine Drive 插件做出贡献的开发者、测试者和用户！
