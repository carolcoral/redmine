# 项目记忆

## 项目概要
- Redmine 项目，基于 Rails 8.1.3，Ruby >= 3.2.0, < 4.1.0
- 使用 rbenv 管理 Ruby 版本，当前项目版本 3.3.6
- 有一键启动脚本 `setup-redmine.sh`

## setup-redmine.sh 关键信息
- 已添加 `setup_ruby_env()` 函数自动管理 Ruby 版本（rbenv/rvm 兼容）
- macOS BSD sed 语法注意：不支持 `\+`，需用 `*` 替代
- 版本比较采用整数化方式：`v1*1000000 + v2*1000 + v3`
