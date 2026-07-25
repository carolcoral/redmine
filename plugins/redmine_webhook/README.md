# Redmine Webhook Plugin 🚀

[![Redmine](https://img.shields.io/badge/Redmine-6.1%2B-blue)](https://www.redmine.org/)
[![Ruby](https://img.shields.io/badge/Ruby-2.7%2B-red)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.4-orange)](CHANGELOG.md)

Redmine 钉钉通知插件，支持任务状态变更实时通知与智能提醒。

## ✨ 核心功能

### 🔔 任务提醒
- **自动提醒**：每日定时提醒无任务成员，支持自定义时间与模板
- **智能过滤**：仅提醒在岗且无指派任务的成员
- **多项目支持**：涵盖当前项目及所有父子项目
- **角色筛选**：按角色精准提醒，排除内置角色
- **多容器部署**：数据库分布式锁，自动防重

### 💬 智能@提醒
- **手机号强提醒**：配置用户手机号实现弹窗+红色标记提醒
- **多用户支持**：多个用户共享手机号时全部收到提醒
- **自动识别**：模板中使用 `${assigned_to}` 变量自动触发

### 🔄 子项目同步
- **一键同步**：将配置批量同步到所有子项目
- **递归支持**：不限层级的多级子项目
- **原子操作**：事务保证数据一致性

### 📝 灵活配置
- **状态多选**：自由选择触发通知的任务状态
- **模板定制**：支持 Markdown/HTML 格式，9 个内置变量
- **签名验证**：支持钉钉机器人安全签名

## 🚀 快速安装

```bash
cd /path/to/redmine/plugins
git clone https://github.com/carolcoral/redmine_webhook.git redmine_webhook
cd /path/to/redmine
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
touch tmp/restart.txt
```

> 💡 **详细安装与配置指南**：查看 [USAGE.md](USAGE.md)

## ⚙️ 快速配置

### 钉钉机器人
1. 群设置 → 智能群助手 → 添加机器人 → 自定义
2. 复制 Webhook URL

### 插件基础配置
进入 **项目 → Webhook** 菜单：
- ✅ 启用 Webhook
- 🔗 填写 Webhook 地址
- 🔑 填写密钥令牌（可选）
- 📝 编辑通知模板

## 📋 模板变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `${user}` | 操作用户 | 张三 |
| `${task}` | 任务标题 | 修复登录 bug |
| `${status}` | 当前状态 | 进行中 |
| `${project}` | 项目名称 | 网站开发 |
| `${url}` | 任务链接 | http://redmine.example.com/issues/123 |
| `${notes}` | 备注信息 | 已修复验证问题 |
| `${priority}` | 优先级 | 紧急 |
| `${tracker}` | 跟踪类型 | Bug |
| `${assigned_to}` | 指派人 | 李四 |

### 模板示例

**基础通知：**
```
${user} 更新了任务 "${task}"
状态：${status} | 项目：${project}

查看详情：${url}
```

**Markdown 格式：**
```markdown
## 📋 ${project} - 任务更新

**任务：** ${task}
**状态：** ${status}
**操作人：** ${user}

[查看详情](${url})
```

> 💡 **更多模板示例与最佳实践**：查看 [USAGE.md - 模板编写指南](USAGE.md#模板编写指南)

## 🔗 相关文档

- 📖 [详细使用教程](USAGE.md) - 完整的配置和使用指南
- 📋 [更新日志](CHANGELOG.md) - 版本历史和变更记录
- 🐛 [问题反馈](https://github.com/carolcoral/redmine_webhook/issues)
- ⭐ [项目主页](https://github.com/carolcoral/redmine_webhook)

## 📄 许可证

MIT License - [carolcoral](https://github.com/carolcoral)
