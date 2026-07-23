# Redmine Third Login Plugin

[![Author](https://img.shields.io/badge/Author-carolcoral-brightgreen)](https://github.com/carolcoral)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue)](https://github.com/carolcoral/redmine_third_login/releases)
[![Redmine](https://img.shields.io/badge/Redmine-6.1.1-red)](https://www.redmine.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

一个功能完善的Redmine登录方式扩展插件，支持本地登录、LDAP登录和钉钉扫码登录。

## 功能特性

### 🎯 登录方式增强
- 在现有登录页面添加登录方式下拉选择器
- 支持三种登录方式：本地登录、LDAP登录、钉钉扫码登录
- 与Redmine原生UI风格保持一致

### 🔧 动态表单适配
- 根据选择的登录方式动态显示相应的登录字段
- 本地登录：保持现有用户名/密码字段
- LDAP登录：显示LDAP专用的用户名/密码字段
- 钉钉扫码登录：隐藏传统输入字段，显示二维码扫描区域

### 📱 钉钉扫码登录
- 集成钉钉开放平台扫码登录API
- 动态生成并显示有效的钉钉登录二维码
- 扫码成功后自动匹配Redmine用户并完成登录
- 通过手机号进行用户匹配验证

### 🔒 用户匹配机制
- 利用Redmine用户表中的"手机号"自定义字段
- 实现钉钉用户与Redmine用户的精准匹配
- 友好的错误提示和处理机制

## 系统要求

- Redmine 6.1.1 或更高版本
- Ruby 3.0 或更高版本
- Rails 6.1 或更高版本
- 网络可访问钉钉开放平台

## 安装说明

### 1. 下载插件

```bash
cd {REDMINE_ROOT}/plugins
git clone https://github.com/carolcoral/redmine_third_login.git
```

### 2. 安装依赖

```bash
cd {REDMINE_ROOT}
bundle install
```

### 3. 执行数据库迁移（如有必要）

```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 4. 重启Redmine服务

```bash
# 根据你的部署方式重启服务
touch tmp/restart.txt  # For Passenger
# 或
systemctl restart redmine  # For systemd
```

### 5. 配置插件

1. 登录Redmine管理员账户
2. 进入 管理 → 插件
3. 找到 "Redmine Third Login Plugin"
4. 点击 "配置"
5. 填写钉钉配置信息并保存

## 配置说明

### 钉钉开放平台配置

1. **创建钉钉应用**
   - 登录 [钉钉开放平台](https://open.dingtalk.com/)
   - 创建企业内部应用
   - 获取应用的 **AppKey** 和 **AppSecret**

2. **配置应用权限**
   - 添加权限：企业内部应用免登
   - 配置回调域名：你的Redmine地址

3. **插件配置**
   - App ID: 填写钉钉应用的 AppKey
   - App Secret: 填写钉钉应用的 AppSecret
   - 启用登录方式: 选择需要的登录方式

### LDAP配置（如使用LDAP登录）

1. 确保Redmine已配置LDAP认证源
2. 在插件设置中启用LDAP登录
3. 系统会自动检测可用的LDAP认证源

## 手机号字段配置

插件通过手机号匹配Redmine用户，需要在Redmine中添加自定义字段：

1. 进入 管理 → 自定义字段
2. 点击 "新建自定义字段"
3. 类型选择 "文本"
4. 名称填写 **手机号**（必须与这个名称完全一致）
5. 应用于 "用户"
6. 保存并为用户添加手机号信息

## 使用说明

### 管理员操作

1. **配置插件**
   - 在插件设置页面配置钉钉AppID和AppSecret
   - 选择启用的登录方式
   - 保存配置

2. **管理用户手机号**
   - 确保所有需要使用钉钉登录的用户都有手机号信息
   - 手机号必须与钉钉账号绑定的手机号一致

### 普通用户使用

1. **选择登录方式**
   - 在登录页面选择需要的登录方式
   - 系统会根据选择显示相应的登录界面

2. **钉钉扫码登录**
   - 选择 "钉钉扫码登录"
   - 使用钉钉扫描二维码
   - 确认登录后自动跳转到Redmine

3. **切换登录方式**
   - 可以随时切换不同的登录方式
   - 系统会动态更新显示相应的登录表单

## 故障排查

### 常见问题

#### 1. 钉钉二维码无法生成

**原因**: 
- 钉钉AppID或AppSecret配置错误
- 网络无法访问钉钉API

**解决**:
- 检查插件配置中的AppID和AppSecret
- 确保服务器可以访问 https://oapi.dingtalk.com
- 查看Redmine日志获取详细错误信息

#### 2. 扫码后提示"未找到匹配的Redmine用户"

**原因**: 
- Redmine用户没有配置手机号
- 手机号与钉钉账号不一致

**解决**:
- 检查用户是否添加了"手机号"自定义字段
- 确认手机号与钉钉账号绑定的手机号完全一致
- 查看Redmine日志确认手机号匹配情况

#### 3. LDAP登录选项不显示

**原因**: 
- Redmine未配置LDAP认证源
- LDAP认证源配置错误

**解决**:
- 在Redmine中正确配置LDAP认证源
- 确保LDAP服务器可正常连接
- 检查插件设置中是否启用了LDAP登录

#### 4. 插件安装后页面样式错乱

**原因**: 
- 浏览器缓存问题
- CSS文件未正确加载

**解决**:
- 清除浏览器缓存
- 检查浏览器控制台是否有CSS加载错误
- 重启Redmine服务确保静态文件正确加载

### 日志查看

插件会记录详细的日志信息到Redmine日志文件：

```bash
# 查看日志
tail -f {REDMINE_ROOT}/log/production.log | grep "RedmineThirdLogin"
```

日志中包含：
- 二维码生成过程
- 钉钉API调用结果
- 用户匹配情况
- 错误信息和堆栈追踪

## 安全建议

1. **保护AppSecret**
   - 不要在日志中记录AppSecret
   - 定期更换AppSecret
   - 限制钉钉应用的访问权限

2. **HTTPS传输**
   - 建议使用HTTPS协议
   - 确保回调地址使用HTTPS

3. **用户匹配安全**
   - 手机号字段仅供登录匹配使用
   - 限制普通用户查看他人手机号

## 性能优化

1. **二维码缓存**
   - 二维码有效期为5分钟
   - 超过有效期需要重新生成

2. **API调用优化**
   - 钉钉API调用有频率限制
   - 错误处理包含重试机制

## 开发说明

### 代码结构

```
redmine_third_login/
├── app/
│   ├── controllers/
│   │   └── dingtalk_login_controller.rb  # 钉钉登录控制器
│   ├── helpers/
│   │   └── dingtalk_login_helper.rb      # 钉钉登录助手
│   └── views/
│       ├── account/
│       │   └── _login_type_selector.erb  # 登录方式选择器
│       └── settings/
│           └── _redmine_third_login_settings.erb  # 插件设置
├── assets/
│   ├── javascripts/
│   │   └── redmine_third_login.js        # JavaScript逻辑
│   └── stylesheets/
│       └── redmine_third_login.css       # 样式文件
├── config/
│   ├── locales/
│   │   ├── en.yml                        # 英文翻译
│   │   └── zh.yml                        # 中文翻译
│   └── routes.rb                         # 路由配置
├── lib/
│   ├── redmine_third_login.rb            # 主模块
│   └── redmine_third_login/
│       ├── hooks.rb                      # 钩子定义
│       └── user_patch.rb                 # User模型扩展
├── init.rb                               # 插件初始化
├── Gemfile                               # 依赖管理
└── README.md                             # 本文档
```

### 技术栈

- **后端**: Ruby on Rails, HTTParty
- **前端**: Vanilla JavaScript, CSS3
- **API**: 钉钉开放平台API
- **UI**: Redmine原生UI风格

## 贡献指南

欢迎提交Issue和Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 版本历史

### v1.0.0 (2025-03-02)
- 初始版本发布
- 支持本地登录、LDAP登录、钉钉扫码登录
- 完整的错误处理和日志记录
- 中英文双语支持

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 作者信息

- **作者**: carolcoral
- **GitHub**: [https://github.com/carolcoral](https://github.com/carolcoral)
- **项目地址**: [https://github.com/carolcoral/redmine_third_login](https://github.com/carolcoral/redmine_third_login)

## 致谢

- Redmine开源项目团队
- 钉钉开放平台
- 所有贡献者和使用者

---

⭐ 如果这个项目对你有帮助，请给个Star支持一下！
