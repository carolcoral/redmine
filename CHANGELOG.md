# CHANGELOG

本仓库（基于 Redmine 的企业定制部署）的演进历史。上游内核变更不在此记录，见 [Redmine 官方 CHANGELOG](doc/CHANGELOG)。

格式参考 [Keep a Changelog](https://keepachangelog.com/)，按时间倒序。

## [2026-11-23] 上游同步：内核更新至 Redmine 7.0.3

- 合并官方 `github/redmine` 主分支 84 个提交，落后清零；**与本地改动零冲突**（本地从未修改内核代码）
- 内核关键变更：
  - 安全：Textile 格式化器补齐 HTML 白名单净化、`back_url` 校验加固（拒绝反斜杠/控制字符）、忘记密码重置拒绝已过期密码、OAuth token scope 权限管控
  - 重构：Wiki 工具栏由 jsToolBar 替换为服务端渲染 + Stimulus 控制器，并新增插件扩展点（插件可添加工具栏按钮/菜单）
  - 性能：附件/Wiki ZIP 下载流式传输降低内存、MariaDB 搜索慢查询修复、favicon 支持代理缓存
  - 依赖：Rails 8.1.4.1、Nokogiri 1.19.7+、net-ldap 0.21、pg 1.7 等
- 新增 `github` remote 用于后续上游同步；仓库远端整合为 `origin`（`cnb.cool/xindu.site/redmine`），清理冗余分支，全量 tag（237 个）入库

## [2026-11-18 ~ 2026-11-20] OIDC 单点登录插件 v1.0.0

自研插件 `redmine_oidc`（详见 [plugins/README.md](plugins/README.md)），面向 SADP 平台（OIDC Provider）的完整单点登录集成。

### 新增

- OIDC Authorization Code 登录、Discovery 自动发现、登录按钮跨主题自适应（样式内联，不依赖资产预编译）
- 登出策略：优先调用平台专有登出 API（`/api/v1/auth/logout` + refreshToken，跳转前同步调用）；平台标准 `/connect/logout` 跳转默认关闭（平台端点带会话回 400），`prompt=login` 强制重新认证兜底
- 自动建号：登录名优先级（工号→邮箱前缀→用户名）、中英文姓名拆分规则、自动分配默认角色/项目（项目与角色都配置才生效）
- 设置页：client_secret 加密存储、连通性测试、密钥缺失告警、登录按钮图标自定义、`auto_redirect` 自动跳转、`hide_local_login` 隐藏本地登录

### 修复

- token 端点 400/302 时自动回退 `client_secret_post` 认证
- 平台业务失败包在 HTTP 200 内（`code != 0`）的误判 → 解析响应体并记录可观测日志
- 登录按钮在生产环境（Propshaft 资产清单缺失）样式 404 退化为裸链接
- 退出后无法切换账号、`/connect/logout` 带 `post_logout_redirect_uri` 回 400、设置保存 permit 白名单等

## [2026-11-03] Task Push 插件迭代（v1.2.3 ~ v1.2.5）

- 自定义字段解绑存在性依赖，空值照常推送
- OCR 引擎 tesseract 未安装时回退内置识别器；设置页补全引擎下拉选项
- 修复 token 过期导致推送静默失败；日志关键字统一收口 `LOG_TAG`

## [2026-10-29 ~ 2026-10-30] 仓库迁移与主题适配

- 仓库迁移至 CNB；插件 / 主题 / CodeBuddy 配置纳入版本库；配置文件脱敏入库
- setup 脚本新增启动前检查（凭据校验）
- TW 主题适配 Redmine 7.0.2 版面；视觉风格调整为亮色 v4.2.0
- Task Push：修复 token 过期静默失败、日志规范
