# Redmine Logo 插件

为 Redmine 6.1.x 提供可自定义的 Logo 功能，支持文字/图片、多节点部署、系统 URL 覆盖和 29 种语言。

![截图](screenshots/2.png)

## 特性

- **文字与图片 Logo**: 自定义文字（最多30字符）或图片上传（JPG/PNG/GIF/SVG）
- **Base64 存储**: 图片存储在数据库中，支持多节点
- **类型切换**: 文字/图片无缝切换，不丢失设置
- **系统 URL 覆盖**: 全局替换默认 `http://localhost:3000`
- **29 种语言**: 完整的 UI 本地化，包括 RTL 支持
- **AJAX 上传**: 实时上传带预览
- **自定义头部**: 可插入 `<style>`/`<script>` 标签
- **响应式设计**: 适配移动设备

## 系统要求

- Redmine 6.1.0+
- Ruby 2.7+
- Rails 6.1+

## 安装

```bash
cd /path/to/redmine/plugins
git clone https://github.com/carolcoral/redmine_logo.git redmine_logo
cd /path/to/redmine
bundle install
touch tmp/restart.txt  # 重启 Redmine
```

## 配置

**访问**: 以管理员身份登录 → **管理 → Logo 管理**

1. **启用/禁用**: 切换 Logo 显示
2. **系统 URL**（可选）: 替换默认 `http://localhost:3000`
3. **Logo 类型**: 选择 **文字** 或 **图片**
   - **文字**: 输入文字（≤30 字符）、颜色、字重
   - **图片**: 上传图片（转换为 base64）
4. **显示**: 设置位置、边距
5. **自定义头部**（可选）: 插入 `<style>`/`<script>` 标签
6. **保存**: 点击 **保存**

### 多节点部署

完全兼容多节点部署：

- **Base64 存储**: 图片在数据库，无需文件系统
- **原子配置**: 所有设置在 `Setting.plugin_redmine_logo` 中
- **备份简单**: 数据库备份包含所有内容

### 系统 URL 覆盖

全局替换默认 `http://localhost:3000`（邮件、插件、URL）：

- 输入完整 URL: `https://redmine.example.com`
- 验证: `bundle exec rails runner "puts home_url"`
- 详见 [CUSTOM_SYSTEM_URL_README.md](CUSTOM_SYSTEM_URL_README.md)

## 使用示例

- **文字**: "MyCompany"（首字母橙色、粗体、左对齐）
- **图片**: 上传 → 预览 → 保存（最大 120px 宽度）
- **自定义头部**: 添加分析或自定义 CSS/JS

## 文件结构

```
redmine_logo/
├── init.rb                                  # 插件注册和设置
├── app/
│   ├── controllers/                         # 图片上传处理和 base64 转换
│   ├── helpers/                             # Logo 渲染逻辑
│   └── views/
│       └── logo_settings/
│           └── _form.html.erb              # 配置表单（AJAX 上传、类型切换）
├── config/
│   ├── locales/                            # 29 种语言翻译
│   │   ├── en.yml                          # 英语
│   │   ├── zh.yml                          # 简体中文
│   │   ├── zh-TW.yml                       # 繁体中文
│   │   ├── de.yml                          # 德语
│   │   ├── fr.yml                          # 法语
│   │   ├── es.yml                          # 西班牙语
│   │   ├── ja.yml                          # 日语
│   │   ├── ko.yml                          # 韩语
│   │   ├── ar.yml                          # 阿拉伯语
│   │   ├── fa.yml                          # 波斯语
│   │   └── ...（20 多种其他语言）
│   └── routes.rb                           # 插件路由
├── lib/redmine_logo/
│   ├── system_url_override.rb             # 系统 URL 覆盖逻辑
│   └── view_listener.rb                   # 视图钩子 & CSS 生成
├── screenshots/                           # 插件截图
├── CUSTOM_SYSTEM_URL_README.md           # 系统 URL 覆盖技术文档
├── README.md                             # 英文文档
└── README-zh.md                          # 中文文档
```

## 浏览器兼容性

- ✅ Chrome 20+
- ✅ Firefox 29+
- ✅ Safari 12.1+
- ✅ Edge 18+
- ⚠️ IE11: 颜色选择器回退为文本输入

## 技术细节

- **存储**: 纯数据库（图片使用 base64）
- **钩子**: `view_layouts_base_html_head`, `view_layouts_base_body_bottom`
- **CSS 前缀**: `redmine_logo-`
- **兼容性**: Chrome 20+, Firefox 29+, Safari 12.1+, Edge 18+

## 故障排除

**Logo 不显示**
- 检查启用状态，清除缓存（Ctrl+Shift+R），验证设置
- 重启 Redmine，检查浏览器控制台

**图片上传失败**
- 检查 JavaScript 控制台，验证权限
- 查看 Redmine 日志，检查格式（JPG/PNG/GIF/SVG）
- 确保设置保留，注意：base64 存储（无文件）

**URL 覆盖不工作**
1. 确认设置已保存
2. 重启 Redmine
3. 清理缓存：`RAILS_ENV=production bundle exec rake tmp:cache:clear`
4. 在控制台验证：`bundle exec rails runner "puts home_url"`

**切换时设置不保留**
- 启用 JavaScript，清除缓存，检查控制台
- 验证数据库连接（base64 存储）

## 更新日志

### 版本 1.0.3 (2026-02-13)
- **Base64 图片存储**: 图片存储在数据库，支持多节点
- **设置保留**: 切换文字/图片类型不丢失数据
- **Bug 修复**: 修复显示问题、预览清除、类型切换
- **多语言**: 更新所有 29 种语言文件

### 版本 1.0.2 (2026-02-04)
- 修复按钮抖动、优化插入、实时类型切换

### 版本 1.0.1 (2026-02-03)
- 自定义头部内容、CSS 隔离、移动端优化

### 版本 1.0.0 (2026-02-02)
- 初始版本

## 许可证

MIT 许可证

## 支持

- GitHub: https://github.com/carolcoral/redmine_logo
- Issues: https://github.com/carolcoral/redmine_logo/issues
- 中文文档: README-zh.md
