# Changelog

> Redmine++ 7.0.0 发行说明 · Release Notes
> 历史完整变更明细见 [`doc/CHANGELOG`](doc/CHANGELOG)。

[![Redmine++](https://img.shields.io/badge/Redmine++-7.0.0-cc0000)](https://github.com/redmine-plus-plus/redmine-plus-plus)
[![Released](https://img.shields.io/badge/Released-2026--06--30-blue)](doc/CHANGELOG)
[![Modules](https://img.shields.io/badge/Modules-32-6f9d33)](doc/CHANGELOG)

本次发布涵盖 **32 个模块分类**，包含框架升级、原生 Webhook、预览能力增强、
界面体系重构与多项性能 / 安全改进。

---

## [7.0.0] — 2026-06-30

### Platform / 平台与依赖
- `Feature #43205` 升级至 **Rails 8**
- `Feature #43650` 支持 **Ruby 4.0**
- `Patch #42737` HTML 过滤由 `html-pipeline` 迁移至 **Loofah**
- `Patch #43388` 移除 Internet Explorer 兼容 CSS
- `Patch #43845` 移除 Raphael.js 依赖，转向原生 **SVG API**

### Accounts / Authentication / 账号与认证
- `Feature #43808` 默认管理员邮箱改为 `admin@dummy.invalid`（更清晰）
- `Feature #44052` 默认启用 **Sudo 模式**

### Administration / 管理
- `Feature #44062` 管理信息页新增 Environment 分区

### Attachments / 附件与预览
- `Feature #8959` 支持 **Microsoft Office / LibreOffice Writer** 文件预览
- `Feature #22483` PDF 附件与仓库条目改为**内联预览**而非下载
- `Feature #43943` 新增 **AVIF** 图像支持
- `Defect #44126` 修复 SVG 附件以 XML 源码而非图像预览
- `Defect #44029` 修复预览中宽表格溢出容器边框
- `Defect #44186` 修复超长扩展名文件上传失败

### Calendar / 日历
- `Feature #43728` 今日指示器由黄色背景改为蓝色日期圆点

### Custom fields / 自定义字段
- `Feature #44129` 日期格式自定义字段支持**相对默认值**

### Code cleanup / 代码清理
- `Patch #43206` 移除废弃的 `icon-*` 样式类
- `Patch #43276` 以 `form.textarea` 取代 `form.text_area`
- `Patch #43321` 移除废弃方法 `ApplicationHelper#render_if_exist`
- `Patch #43429` 移除 `acts_as_watchable` 未用方法
- `Patch #43643` Textile 处理对齐 CommonMark（统一使用 Loofah）
- `Patch #43702` 移除未用 CSS 规则
- `Patch #43745` 将内联附件解析逻辑移至 scrubbers
- `Patch #43802` 示例与测试中避免使用非保留域名
- `Patch #44074` 移除 twofa token 查询中冗余 scope
- `Patch #44117` 移除过时的 `.hgignore`
- `Patch #44169` 上下文菜单控制器重构为命名空间子控制器
- `Patch #44195` `.gitignore` 新增 `__pycache__`
- `Defect #42408` 修正 JS 函数名拼写 `toggleExpendCollapseIcon`

### Documentation / 文档
- `Patch #43800` 在 `doc/licenses` 下补充第三方组件许可文件
- `Patch #43822` CommonMark 帮助示例采用逻辑 CSS 属性以支持 RTL
- `Patch #43931` 移除 `.github/PULL_REQUEST_TEMPLATE.md`（已禁用 PR）

### Email notifications / 邮件通知
- `Feature #2716` 用户可选项：自动将经办人加入观察者
- `Feature #37978` 新增「仅关注对象」邮件通知选项
- `Defect #38513` 修正 `MIME-Version` 邮件头字段大小写
- `Defect #44173` 密码重置安全通知补充 IP 地址

### Filters / 过滤器
- `Defect #38055` 修复自定义字段「不包含」操作符忽略空值问题单

### Gantt / 甘特图
- `Feature #43397` 甘特图代码拆分为视图 + **Stimulus 控制器**
- `Feature #43678` 改善 RTL 环境下的甘特图表现

### Gems support / 依赖更新
- `Patch #43323` RuboCop Performance → 1.26 · `Patch #43324` Rubyzip → 3.4
- `Patch #43395` roadie-rails → 3.4 · `Patch #43396` propshaft → 1.3
- `Patch #43408` Commonmark → 2.5 · `Patch #43437` RuboCop → 1.88
- `Patch #43438` RuboCop Rails → 2.34 · `Patch #43465` pg → 1.6
- `Patch #43466` sqlite3 → 2.9 · `Patch #43472` Mail → 2.9
- `Patch #43594` Commonmarker → 2.8 · `Patch #43981` net-ldap → 0.20
- `Patch #44032` Trilogy → 2.12 · `Patch #44139` Rouge → 5.0
- `Patch #44200` I18n → 1.15

### Groups / 用户组
- `Patch #43640` 用户视图支持批量增删组内成员

### Hook requests / 钩子
- `Patch #43084` 新增 `view_issues_edit_top` 钩子以定制问题编辑表单

### I18n / 国际化
- `Feature #4507` 姓名字段顺序遵循「用户显示格式」设置
- `Patch #44065` 移除未使用的 i18n key

### Importers / 导入
- `Defect #41434` 修复首行带换行的 CRLF CSV 导入失败
- `Feature #43363` 改进导入视图的错误信息展示
- `Feature #43918` 废弃损坏的 Mantis / Trac 迁移 rake 任务

### Issues / 问题
- `Feature #9432` 问题私密标记支持默认值
- `Feature #31518` 新问题截止日期支持相对今天的偏移
- `Feature #43085` 引用内容时滚动至备注区而非编辑表单顶部
- `Feature #43885` 问题与上一/下一链接样式对齐分页按钮
- `Feature #43895` 新安装默认关闭「以今天作为新问题开始日期」
- `Feature #43969` 子任务 / 关联问题区「添加」链接增加图标
- `Feature #43996` 经办人下拉新增用户 / 组排序设置
- `Feature #44015` 经办人下拉支持「按用户组」展示

### Issues filter / 问题过滤
- `Feature #43968` `IssueQuery` 的 `estimated_hours` / `spent_time` 过滤支持 `0:45h` 格式

### Issues list / 问题列表
- `Feature #43615` 问题列表所有时间跟踪列**右对齐**

### Performance / 性能
- `Defect #43742` 修复缺失 `#wrapper` 定位导致的回流开销
- `Defect #43838` 修复大量用户实例下 `@login` 提及渲染性能问题
- `Feature #43957` 改进工作流更新性能
- `Feature #44194` 缓存用户提及自动补全响应，减少冗余请求
- `Patch #43934` 优化 `Issue#visible_journals_with_index` 预加载（Gravatar 关闭时跳过 email）
- `Patch #44190` 限制提及初始建议数量以提升性能

### Project settings / 项目设置
- `Feature #44013` 项目「成员」标签页增加用户组链接

### Projects / 项目
- `Feature #37480` 项目成员关系支持 CSV 导出
- `Feature #43818` 所有项目页面（非仅概览）显示关闭项目警告

### REST API / 接口
- `Feature #43569` Wiki 页面 API 响应新增所属项目
- `Feature #43938` 记录 API / Atom 访问密钥**最后使用时间**
- `Feature #44153` 问题自定义字段 API 响应包含关联项目
- `Defect #44152` 修复非问题自定义字段不返回可见角色
- `Defect #44165` 修复 API Key 认证失败时错误返回 Basic 质询

### Roadmap / 路线图
- `Feature #39882` 路线图视图高亮选中版本

### SCM / 版本控制
- `Defect #43965` 修复变更集视图上/下一条链接顺序与列表不一致
- `Patch #42762` 改进仓库页 Git / Mercurial 修订图

### Text formatting / 文本格式化
- `Feature #42444` 允许在文本格式中使用 CSS `text-decoration`
- `Feature #43950` 支持将表格粘贴为 CommonMark / Textile 表格
- `Feature #44061` CommonMark 文本域支持 **Tab / Shift+Tab** 缩进选中行

### Third-party libraries / 第三方库
- `Patch #44018` Chart.js → 4.5.1 并迁移至 ES Modules
- `Patch #44038` Tabler Icons → v3.43.0

### Time tracking / 时间跟踪
- `Feature #15167` 隐藏耗时报表中未使用的 Options 区
- `Feature #43948` `TimeEntryQuery` 的 `hours` 过滤支持 `0:45h` 格式

### UI / 界面
- `Feature #31353` 顶栏用户相关链接升级为**独立用户菜单**
- `Feature #34917` 非破坏性解除动作标签统一使用「Remove」
- `Feature #43256` 引入 **Open Color** 统一 CSS 色板
- `Feature #43279` 简化问题编辑表单 fieldset 边框
- `Feature #43381` 提升文件上传错误信息可见性
- `Feature #43390` 移除 body 上 `avatars-on/off` 类
- `Feature #43506` 在 HTML 元素声明文本方向，改善 RTL/LTR
- `Feature #43515` 移除 `rtl.css`，以逻辑属性整合至 `application.css`
- `Feature #43563` 增加 `#content` 顶部内边距提升可读性
- `Feature #43575` 清理盒式 UI 元素边框与内边距
- `Feature #43658` 默认 Gravatar 选项新增「Color」
- `Feature #43700` 核心 CSS 以逻辑属性替代物理属性（RTL）
- `Feature #43797` 附件列表以**文件类型图标**替代回形针
- `Feature #43805` 为更多 MIME 类型更新文件图标
- `Feature #43824` 增加页面两侧间距改善观感
- `Feature #43825` 用户搜索对话框保留勾选选择
- `Feature #43836` 统一问题详情页分隔符间距
- `Feature #43937` **导航栏式页头**重构，视觉更轻量
- `Feature #43988` 侧栏选中链接颜色对齐主菜单指示
- `Feature #44071` 上下文菜单宽度自适应避免标签换行
- `Feature #44111` 统一路线图 / 新闻 / 文档索引页布局
- `Defect #25114` 修复主题 `#content` 相对定位时右键菜单错位
- `Defect #43588` 修复问题视图右列误用 `splitcontentleft` 类
- `Defect #43876` 修复字号放大时输入框 / 按钮文字被裁切

### Webhooks / 自动化
- `Feature #29664` 内置 **Webhook 触发器**

### Wiki / 维基
- `Feature #43978` 支持将所有 Wiki 页面**导出为 ZIP**

---

## 版本时间线 / Timeline

| 版本 | 日期 | 摘要 |
| --- | --- | --- |
| `7.0.0` | 2026-06-30 | Rails 8 · 原生 Webhook · 预览与界面体系重构 |
| `6.1.3` | 2026-06-15 | 维护更新 |
| `6.1.0` | 2025-11-30 | 上一主版本线 |

> 完整历史（含历史缺陷修复与更早版本）请查阅 [`doc/CHANGELOG`](doc/CHANGELOG)。
