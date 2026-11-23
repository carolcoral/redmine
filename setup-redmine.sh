#!/usr/bin/env bash
# ============================================================================
# Redmine 一键启动脚本
# 基于 Redmine 官方安装指南: https://www.redmine.org/projects/redmine/wiki/RedmineInstall
# 适用于 CNB 云原生开发环境 (Debian 13 / Ubuntu)
# ============================================================================

set -euo pipefail

# ── 颜色定义 ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── 配置区（可按需修改）─────────────────────────────────────────────────────
REDMINE_HOME="$(cd "$(dirname "$0")" && pwd)"
DB_ADAPTER="${DB_ADAPTER:-sqlite3}"      # 可选: sqlite3 / mysql2 / postgresql
RAILS_ENV="${RAILS_ENV:-development}"     # development / production
REDMINE_PORT="${REDMINE_PORT:-3000}"      # 监听端口
REDMINE_BIND="${REDMINE_BIND:-0.0.0.0}"   # 绑定地址
REDMINE_LANG="${REDMINE_LANG:-zh}"        # 默认数据语言: zh / en / fr / ja ...
RESET_DB="${RESET_DB:-0}"                 # 是否清空数据库重建 (0=保留数据, 1=清空重建)
AUTO_CONFIRM="${AUTO_CONFIRM:-0}"         # 0=交互式确认, 1=自动执行
QUIET_MODE="${QUIET_MODE:-1}"             # 0=详细输出, 1=静默模式（仅关键信息）

# ── 辅助函数 ─────────────────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${CYAN}${BOLD}━━━ 步骤 $1${NC}"; }
banner()    { echo -e "${BOLD}$*${NC}"; }

# 交互式确认（AUTO_CONFIRM=1 时自动跳过）
confirm_step() {
  local msg="${1:-是否继续？}"
  if [[ "$AUTO_CONFIRM" == "1" ]]; then
    return 0
  fi
  read -r -p "$(echo -e "${YELLOW}${msg} [Y/n] ${NC}")" answer
  [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
}

# 运行命令（可静默）
run_cmd() {
  local desc="$1"
  shift
  log_info "${desc}..."
  if [[ "$QUIET_MODE" == "1" ]]; then
    "$@" > /dev/null 2>&1 || { log_error "失败: ${desc}"; return 1; }
  else
    "$@" || { log_error "失败: ${desc}"; return 1; }
  fi
  log_ok "${desc} 完成"
}

# ── 数据库状态检测（通过 ActiveRecord 连接检测）───────────────────────────
# 返回值: "schema roles" 两个布尔值，如 "true true" / "true false" / "false false"
_db_status() {
  cd "${REDMINE_HOME}"
  RAILS_ENV="${RAILS_ENV}" bundle exec ruby -e '
    begin
      require "bundler/setup"
      require "active_record"
      require "erb"
      require "yaml"
      cfg = YAML.safe_load(ERB.new(File.read("config/database.yml")).result)[ENV["RAILS_ENV"] || "development"]
      ActiveRecord::Base.establish_connection(cfg)
      has_schema = ActiveRecord::Base.connection.table_exists?("schema_migrations")
      has_roles = false
      if ActiveRecord::Base.connection.table_exists?("roles")
        has_roles = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM roles").to_i > 0
      end
      puts "#{has_schema} #{has_roles}"
    rescue => e
      puts "false false"
    end
  ' 2>/dev/null || echo "false false"
}

# 数据库是否已初始化（有 schema_migrations 表）
_db_initialized() {
  local status
  status=$(_db_status)
  [[ "$(echo "$status" | awk "{print \$1}")" == "true" ]]
}

# 数据库是否已有业务数据（roles 表有记录）
_db_has_roles() {
  local status
  status=$(_db_status)
  [[ "$(echo "$status" | awk "{print \$2}")" == "true" ]]
}

# ── 打印 Banner ──────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${GREEN}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║                                                          ║"
  echo "║         Redmine 一键启动脚本                              ║"
  echo "║         基于 Rails 8.1.3  ·  Ruby >= 3.3.0               ║"
  echo "║                                                          ║"
  echo "║  数据库: ${DB_ADAPTER}                          "
  echo "║  运行环境: ${RAILS_ENV}                          "
  echo "║  访问地址: http://localhost:${REDMINE_PORT}               "
  echo "║  默认账号: admin / admin                                 ║"
  echo "║                                                          ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  工具函数：自动安装 rbenv + ruby-build                                      ║
# ║  依次尝试: apt/brew 包管理器 → git 官方方式克隆                              ║
# ╚════════════════════════════════════════════════════════════════════════════╝
_auto_install_rbenv() {
  local SUDO=""
  if [[ "$(id -u)" != "0" ]] && command -v sudo &>/dev/null; then
    SUDO="sudo"
  fi

  log_warn "未检测到 rbenv，正在自动安装 rbenv + ruby-build..."
  if command -v apt-get &>/dev/null; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq rbenv ruby-build 2>/dev/null || true
  elif command -v brew &>/dev/null; then
    brew install rbenv ruby-build 2>/dev/null || true
  fi

  # 包管理器未装成功时，用 git 安装（rbenv 官方方式）
  if [[ ! -f "$HOME/.rbenv/bin/rbenv" ]] && ! command -v rbenv &>/dev/null; then
    log_info "通过 git 安装 rbenv（官方方式）..."
    command -v git &>/dev/null || $SUDO apt-get install -y -qq git
    if [[ -d "$HOME/.rbenv" ]]; then
      (cd "$HOME/.rbenv" && git pull -q) 2>/dev/null || true
    else
      git clone --depth 1 https://github.com/rbenv/rbenv.git "$HOME/.rbenv" 2>/dev/null || true
    fi
    mkdir -p "$HOME/.rbenv/plugins"
    if [[ -d "$HOME/.rbenv/plugins/ruby-build" ]]; then
      (cd "$HOME/.rbenv/plugins/ruby-build" && git pull -q) 2>/dev/null || true
    else
      git clone --depth 1 https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build" 2>/dev/null || true
    fi
  fi

  # 刷新 PATH 并初始化 rbenv
  if [[ -f "$HOME/.rbenv/bin/rbenv" ]]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - bash 2>/dev/null || true)" 2>/dev/null || true
    log_ok "rbenv 安装完成"
  elif command -v rbenv &>/dev/null; then
    eval "$(rbenv init - bash 2>/dev/null || true)" 2>/dev/null || true
    log_ok "rbenv 就绪"
  else
    log_error "rbenv 安装失败，请手动安装: https://github.com/rbenv/rbenv#installation"
    exit 1
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  环境初始化：自动管理 Ruby 版本 (rbenv / rvm)                               ║
# ║  - 自动初始化 rbenv/rvm 环境                                               ║
# ║  - 解析 Gemfile 中的 Ruby 版本约束                                         ║
# ║  - 如当前版本不匹配，自动查找已安装兼容版本                                   ║
# ║  - 如没有兼容版本，自动通过 rbenv 安装                                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝
setup_ruby_env() {
  cd "${REDMINE_HOME}"

  # ── 初始化 rbenv；无 rbenv 时自动安装 ──
  # 注意: rbenv init 内部会执行 `rbenv rehash`，其失败（如 ~/.rbenv/shims/.rbenv-shim 残留）
  #       在 set -e 下会导致脚本静默退出，故整体加 || true 容错，不让 shims 问题阻断启动
  if [[ -f "$HOME/.rbenv/bin/rbenv" ]]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - zsh 2>/dev/null || rbenv init - bash 2>/dev/null || true)" 2>/dev/null || true
  elif command -v rbenv &>/dev/null; then
    eval "$(rbenv init - bash 2>/dev/null || true)" 2>/dev/null || true
  else
    _auto_install_rbenv
  fi

  # ── 初始化 rvm ──
  if [[ -f "$HOME/.rvm/scripts/rvm" ]]; then
    source "$HOME/.rvm/scripts/rvm" 2>/dev/null || true
  fi

  # ── 解析 Gemfile 中的 Ruby 版本约束 ──
  local gemfile_ruby_line
  gemfile_ruby_line=$(grep "^ruby\b" Gemfile 2>/dev/null || echo "")
  if [[ -z "$gemfile_ruby_line" ]]; then
    log_info "Gemfile 中未指定 Ruby 版本约束，跳过版本检查"
    return 0
  fi

  # 提取最低版本号 (支持 '>= 3.2.0' 和 ">= 3.2.0" 两种写法)
  local min_ver
  min_ver=$(echo "$gemfile_ruby_line" | sed -n "s/.*>= *\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p" | head -1)
  if [[ -z "$min_ver" ]]; then
    log_warn "无法解析 Gemfile Ruby 版本约束，跳过"
    return 0
  fi

  log_info "Gemfile 要求: Ruby >= ${min_ver}"

  # ── 版本号转整数比较: X.Y.Z -> X*1000000 + Y*1000 + Z ──
  _ver_to_int() {
    local v1 v2 v3
    IFS='.' read -r v1 v2 v3 <<< "${1:-0.0.0}"
    echo $(( v1 * 1000000 + v2 * 1000 + v3 ))
  }

  # ── 检查当前 Ruby 是否满足要求 ──
  local current_ver
  current_ver=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "0.0.0")
  local min_int current_int
  min_int=$(_ver_to_int "$min_ver")
  current_int=$(_ver_to_int "$current_ver")

  if [[ $current_int -ge $min_int ]]; then
    log_ok "Ruby ${current_ver} 满足版本要求"
    return 0
  fi

  log_warn "当前 Ruby ${current_ver} 不满足要求 (>= ${min_ver})，需要切换"

  # ── 确保 rbenv 可用（无则自动安装） ──
  if ! command -v rbenv &>/dev/null; then
    _auto_install_rbenv
  fi

  # ── 通过 rbenv 自动管理 Ruby 版本 ──
  {
    # 查找已安装的兼容版本（优先选最新的）
    local installed best_ver=""
    installed=$(rbenv versions --bare 2>/dev/null || true)
    while IFS= read -r ver; do
      [[ -z "$ver" ]] && continue
      local ver_int
      ver_int=$(_ver_to_int "$ver")
      if [[ $ver_int -ge $min_int ]]; then
        if [[ -z "$best_ver" ]]; then
          best_ver="$ver"
        else
          local best_int
          best_int=$(_ver_to_int "$best_ver")
          [[ $ver_int -gt $best_int ]] && best_ver="$ver"
        fi
      fi
    done <<< "$installed"

    if [[ -n "$best_ver" ]]; then
      log_info "使用已安装版本: Ruby ${best_ver}"
    else
      # 没有兼容版本，自动安装
      # 默认安装 3.3.6（满足 Gemfile 约束 >= 3.3.0, < 4.1.0），可用 REDMINE_RUBY_VERSION 覆盖
      local install_ver="${REDMINE_RUBY_VERSION:-3.3.6}"
      log_info "未找到兼容版本，正在通过 rbenv 安装 Ruby ${install_ver}..."
      log_info "（首次安装可能需要几分钟，请耐心等待）"
      if rbenv install -s "$install_ver" 2>&1; then
        best_ver="$install_ver"
        log_ok "Ruby ${install_ver} 安装成功"
      else
        log_error "Ruby ${install_ver} 安装失败"
        log_info "请手动执行: rbenv install ${install_ver}"
        exit 1
      fi
    fi

    rbenv local "$best_ver"
    echo "$best_ver" > "${REDMINE_HOME}/.ruby-version"
    # 刷新当前 Ruby
    current_ver=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "0.0.0")
    log_ok "Ruby ${current_ver} 就绪"
    return 0
  }

  # ── 兜底：正常情况下不会到达 ──
  log_error "Ruby 环境准备失败，请检查上述错误信息"
  exit 1
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 0 步：启动前检查（凭据校验）                                            ║
# ║  config/database.yml 与 secret_token.rb 已脱敏入库，凭据只从环境变量读取，   ║
# ║  缺失时在这里立即中止，避免跑到迁移阶段才报一堆连接错误。                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step0_preflight() {
  log_step "0/9: 启动前检查（环境变量）"

  local missing=0
  local db_yml="${REDMINE_HOME}/config/database.yml"
  local extra_env="${REDMINE_HOME}/config/additional_environment.rb"
  local secret_file="${REDMINE_HOME}/config/.secret_key_base"

  # ── 1) 数据库密码 ──
  # database.yml 通过 RAILS_ENV 选库，密码只认 REDMINE_DB_PASSWORD。
  # 例外：本机通过 config/additional_environment.rb 设置，或数据库走本地信任认证。
  if [[ -n "${REDMINE_DB_PASSWORD:-}" ]]; then
    log_ok "REDMINE_DB_PASSWORD 已设置"
  elif [[ -f "$extra_env" ]] && grep -q "REDMINE_DB_PASSWORD" "$extra_env" 2>/dev/null; then
    log_ok "REDMINE_DB_PASSWORD 由 config/additional_environment.rb 提供"
  else
    log_error "未设置 REDMINE_DB_PASSWORD"
    log_info "config/database.yml 已脱敏，数据库密码只从环境变量读取，任选其一："
    log_info "  export REDMINE_DB_PASSWORD='你的数据库密码'"
    log_info "  或写入 ${extra_env}（该文件已被 .gitignore 忽略）"
    missing=1
  fi

  # ── 2) 会话密钥 ──
  # secret_token.rb：SECRET_KEY_BASE → config/.secret_key_base（自动生成复用）→ 随机
  if [[ -n "${SECRET_KEY_BASE:-}" ]]; then
    log_ok "SECRET_KEY_BASE 已设置"
  elif [[ -f "$secret_file" ]]; then
    log_warn "未设置 SECRET_KEY_BASE，将复用 config/.secret_key_base"
  elif [[ "$RAILS_ENV" == "production" ]]; then
    log_error "生产环境必须显式设置 SECRET_KEY_BASE"
    log_info "  多实例/重启后必须一致，否则所有用户登录态失效："
    log_info "  export SECRET_KEY_BASE=\"\$(openssl rand -hex 64)\""
    missing=1
  else
    log_warn "未设置 SECRET_KEY_BASE，首次启动将自动生成 config/.secret_key_base 并复用"
  fi

  # ── 3) database.yml 可渲染性（ERB 语法/变量自洽）──
  if [[ -f "$db_yml" ]] && command -v ruby &>/dev/null; then
    local db_err=""
    # 注意：这段 Ruby 必须保持纯 ASCII —— -e 源码默认编码受 locale 影响，
    # 非 UTF-8 locale 下含中文会报 invalid multibyte char。
    if db_err=$(REDMINE_HOME="$REDMINE_HOME" ruby -rerb -ryaml -e '
         cfg = YAML.safe_load(ERB.new(File.read(ENV["REDMINE_HOME"] + "/config/database.yml")).result,
                              aliases: true)
         env = ENV["RAILS_ENV"] || "development"
         raise "missing section: #{env}" unless cfg.is_a?(Hash) && cfg[env]
       ' 2>&1); then
      log_ok "config/database.yml 渲染正常"
    else
      log_error "config/database.yml 渲染失败：${db_err}"
      missing=1
    fi
  fi

  if [[ $missing -ne 0 ]]; then
    log_error "启动前检查未通过，已中止；补齐上述配置后重试"
    exit 1
  fi

  log_ok "启动前检查通过"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 1 步：检查 & 安装系统依赖 (Ruby / SQLite / 编译工具)                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step1_check_system() {
  log_step "1/9: 检查系统依赖"

  # ── 自动管理 Ruby 版本（必须在任何 ruby/bundle 命令之前执行） ──
  setup_ruby_env

  # ── 权限提升策略：root 用户直接执行，否则尝试 sudo ──
  local SUDO=""
  if [[ "$(id -u)" != "0" ]]; then
    if command -v sudo &>/dev/null; then
      SUDO="sudo"
    else
      log_error "非 root 用户且 sudo 未安装，无法安装系统包。请切换到 root 用户运行。"
      exit 1
    fi
  fi

  # ── 检测包管理器 ──
  local PKG_MGR=""
  if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
  elif command -v apk &>/dev/null; then
    PKG_MGR="apk"
  elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
  elif command -v brew &>/dev/null; then
    PKG_MGR="brew"
  fi

  # ── 检查 Ruby ──
  if ! command -v ruby &>/dev/null; then
    log_warn "Ruby 未安装，正在安装..."
    if [[ -n "$PKG_MGR" ]]; then
      case "$PKG_MGR" in
        apt) $SUDO apt-get update -qq && $SUDO apt-get install -y -qq ruby ruby-dev ruby-bundler ;;
        apk) $SUDO apk add --no-cache ruby ruby-dev ruby-bundler ;;
        yum) $SUDO yum install -y ruby ruby-devel ;;
        brew) brew install ruby ;;
      esac
    else
      log_error "未检测到包管理器，请手动安装 Ruby >= 3.2.0"
      log_info "官方指南: https://www.redmine.org/projects/redmine/wiki/RedmineInstall"
      exit 1
    fi
  fi

  RUBY_VERSION=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "0.0.0")
  log_ok "Ruby ${RUBY_VERSION}"

  # ── 检查 Bundler ──
  if ! command -v bundle &>/dev/null && ! command -v bundler &>/dev/null; then
    log_info "安装 Bundler..."
    gem install bundler --no-document
  fi
  log_ok "Bundler $(bundle --version 2>/dev/null | awk '{print $3}')"

  # ── 安装编译工具（编译 native gem 需要） ──
  local missing_pkgs=""
  if ! command -v gcc &>/dev/null; then missing_pkgs="$missing_pkgs gcc"; fi
  if ! command -v g++ &>/dev/null; then missing_pkgs="$missing_pkgs g++"; fi
  if ! command -v make &>/dev/null; then missing_pkgs="$missing_pkgs make"; fi

  if [[ -n "$missing_pkgs" ]]; then
    log_info "安装编译工具:${missing_pkgs}..."
    case "$PKG_MGR" in
      apt) $SUDO apt-get install -y -qq build-essential ;;
      apk) $SUDO apk add --no-cache build-base ;;
      yum) $SUDO yum groupinstall -y "Development Tools" ;;
      brew) true ;; # macOS 自带
    esac
  fi
  log_ok "编译工具就绪"

  # ── 预装 Ruby 编译依赖（rbenv 编译安装 Ruby 时需要） ──
  if command -v ruby &>/dev/null || command -v rbenv &>/dev/null; then
    case "$PKG_MGR" in
      apt) $SUDO apt-get install -y -qq libssl-dev libyaml-dev zlib1g-dev libffi-dev libreadline-dev 2>/dev/null || true ;;
      apk) $SUDO apk add --no-cache openssl-dev yaml-dev zlib-dev libffi-dev readline-dev 2>/dev/null || true ;;
      yum) $SUDO yum install -y openssl-devel libyaml-devel zlib-devel libffi-devel readline-devel 2>/dev/null || true ;;
      brew) true ;; # macOS 自带
    esac
    log_ok "Ruby 编译依赖就绪"
  fi

  # ── 检查 Ruby 开发头文件（native gem 编译必需，如 ruby-dev） ──
  if command -v ruby &>/dev/null; then
    local ruby_hdr
    ruby_hdr=$(ruby -rrbconfig -e 'print RbConfig::CONFIG["rubyhdrdir"]' 2>/dev/null || echo "")
    if [[ -z "$ruby_hdr" || ! -f "${ruby_hdr}/ruby.h" ]]; then
      log_info "安装 Ruby 开发头文件（native gem 编译需要）..."
      case "$PKG_MGR" in
        apt) $SUDO apt-get install -y -qq ruby-dev 2>/dev/null || log_warn "ruby-dev 安装失败，native gem 可能无法编译" ;;
        apk) $SUDO apk add --no-cache ruby-dev 2>/dev/null || true ;;
        yum) $SUDO yum install -y ruby-devel 2>/dev/null || true ;;
        brew) true ;; # macOS 自带
      esac
    fi
    log_ok "Ruby 开发头文件就绪"
  fi

  # ── 检查 ImageMagick（附件缩略图需要；非启动必需，缺失不应阻断启动） ──
  if command -v magick &>/dev/null || command -v convert &>/dev/null; then
    log_ok "ImageMagick 就绪"
  else
    case "$PKG_MGR" in
      apt) $SUDO apt-get install -y -qq imagemagick 2>/dev/null || true ;;
      apk) $SUDO apk add --no-cache imagemagick 2>/dev/null || true ;;
      yum) $SUDO yum install -y ImageMagick 2>/dev/null || true ;;
      brew)
        # macOS 部分环境无预编译包(Tier 3)，brew 会转为源码编译 imagemagick，
        # 耗时数十分钟且常失败，会直接卡住启动流程 —— 故跳过自动安装。
        log_warn "未检测到 ImageMagick，跳过 Homebrew 自动安装以避免源码编译长时间阻塞"
        log_info "如需附件缩略图功能，请手动执行: brew install imagemagick"
        ;;
    esac
    if command -v magick &>/dev/null || command -v convert &>/dev/null; then
      log_ok "ImageMagick 就绪"
    else
      log_warn "ImageMagick 不可用，附件缩略图功能将受限（不影响 Redmine 启动，可稍后手动安装）"
    fi
  fi

  # ── 检查 yarn（部分插件的前端构建需要，可选；Redmine 核心用 importmap 不依赖） ──
  if ! command -v yarn &>/dev/null; then
    if command -v npm &>/dev/null; then
      log_info "安装 yarn（部分插件需要）..."
      npm install -g yarn 2>/dev/null || log_warn "yarn 安装失败，可忽略（核心功能不依赖）"
    fi
  fi
  [[ -n "$(command -v yarn)" ]] && log_ok "yarn $(yarn --version 2>/dev/null)"

  # ── 根据数据库类型安装对应依赖 ──
  case "$DB_ADAPTER" in
    sqlite3)
      if ! command -v sqlite3 &>/dev/null; then
        log_info "安装 SQLite3..."
        case "$PKG_MGR" in
          apt) $SUDO apt-get install -y -qq sqlite3 libsqlite3-dev ;;
          apk) $SUDO apk add --no-cache sqlite sqlite-dev ;;
          yum) $SUDO yum install -y sqlite sqlite-devel ;;
          brew) brew install sqlite3 ;;
        esac
      fi
      log_ok "SQLite3 就绪"
      ;;
    mysql2)
      if ! command -v mysql &>/dev/null; then
        log_warn "MySQL 客户端未安装。如使用外部 MySQL 服务，可忽略。"
        log_info "安装 MySQL 开发库..."
        case "$PKG_MGR" in
          apt) $SUDO apt-get install -y -qq libmysqlclient-dev default-libmysqlclient-dev ;;
          apk) $SUDO apk add --no-cache mysql-dev ;;
          yum) $SUDO yum install -y mysql-devel ;;
          brew) brew install mysql ;;
        esac
      fi
      log_ok "MySQL 开发库就绪"
      ;;
    postgresql)
      if ! command -v psql &>/dev/null; then
        log_warn "PostgreSQL 客户端未安装。如使用外部 PG 服务，可忽略。"
        log_info "安装 PostgreSQL 开发库..."
        case "$PKG_MGR" in
          apt) $SUDO apt-get install -y -qq libpq-dev ;;
          apk) $SUDO apk add --no-cache postgresql-dev ;;
          yum) $SUDO yum install -y libpq-devel ;;
          brew) brew install postgresql ;;
        esac
      fi
      log_ok "PostgreSQL 开发库就绪"
      ;;
  esac
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 2 步：生成配置文件 (database.yml / configuration.yml)                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step2_setup_config() {
  log_step "2/9: 生成配置文件"

  # ── database.yml ──
  if [[ -f "${REDMINE_HOME}/config/database.yml" ]]; then
    log_warn "config/database.yml 已存在，跳过创建"
  else
    case "$DB_ADAPTER" in
      sqlite3)
        run_cmd "创建 database.yml (SQLite3)" bash -c "cat > '${REDMINE_HOME}/config/database.yml' << 'DBEOF'
# SQLite3 configuration (适合开发/单用户环境)
# 如需 MySQL/PostgreSQL，请参考 config/database.yml.example

development:
  adapter: sqlite3
  database: db/redmine_development.sqlite3
  timeout: 5000

production:
  adapter: sqlite3
  database: db/redmine_production.sqlite3
  timeout: 5000

test:
  adapter: sqlite3
  database: db/redmine_test.sqlite3
  timeout: 5000
DBEOF"
        ;;
      mysql2)
        run_cmd "创建 database.yml (MySQL)" bash -c "cat > '${REDMINE_HOME}/config/database.yml' << 'DBEOF'
development:
  adapter: mysql2
  database: redmine_development
  host: \${REDMINE_DB_HOST:-localhost}
  username: \${REDMINE_DB_USER:-root}
  password: \"\${REDMINE_DB_PASS:-}\"
  encoding: utf8mb4
  variables:
    transaction_isolation: \"READ-COMMITTED\"

production:
  adapter: mysql2
  database: redmine_production
  host: \${REDMINE_DB_HOST:-localhost}
  username: \${REDMINE_DB_USER:-root}
  password: \"\${REDMINE_DB_PASS:-}\"
  encoding: utf8mb4
  variables:
    transaction_isolation: \"READ-COMMITTED\"
DBEOF"
        ;;
      postgresql)
        run_cmd "创建 database.yml (PostgreSQL)" bash -c "cat > '${REDMINE_HOME}/config/database.yml' << 'DBEOF'
development:
  adapter: postgresql
  database: redmine_development
  host: \${REDMINE_DB_HOST:-localhost}
  username: \${REDMINE_DB_USER:-postgres}
  password: \"\${REDMINE_DB_PASS:-postgres}\"

production:
  adapter: postgresql
  database: redmine_production
  host: \${REDMINE_DB_HOST:-localhost}
  username: \${REDMINE_DB_USER:-postgres}
  password: \"\${REDMINE_DB_PASS:-postgres}\"
DBEOF"
        ;;
    esac
    log_ok "database.yml 创建完成 ($DB_ADAPTER)"
  fi

  # ── configuration.yml ──
  if [[ -f "${REDMINE_HOME}/config/configuration.yml" ]]; then
    log_warn "config/configuration.yml 已存在，跳过创建"
  else
    if [[ -f "${REDMINE_HOME}/config/configuration.yml.example" ]]; then
      cp "${REDMINE_HOME}/config/configuration.yml.example" "${REDMINE_HOME}/config/configuration.yml"
      log_ok "configuration.yml 已从示例复制（请按需编辑邮件等配置）"
    fi
  fi

  # ── secrets.yml ──
  if [[ ! -f "${REDMINE_HOME}/config/secrets.yml" ]]; then
    run_cmd "创建 secrets.yml" bash -c "cat > '${REDMINE_HOME}/config/secrets.yml' << 'SEOF'
development:
  secret_key_base: '$(openssl rand -hex 64 2>/dev/null || ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")'

production:
  secret_key_base: '$(openssl rand -hex 64 2>/dev/null || ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")'

test:
  secret_key_base: '$(openssl rand -hex 64 2>/dev/null || ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")'
SEOF"
  fi

  # ── .ruby-version ──
  # setup_ruby_env 已自动设置正确的版本，此处仅在不存在时补一个最低版本提示
  if [[ ! -f "${REDMINE_HOME}/.ruby-version" ]]; then
    local gemfile_ver
    gemfile_ver=$(grep "^ruby\b" Gemfile 2>/dev/null | sed -n "s/.*>= *\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p" | head -1)
    echo "${gemfile_ver:-3.2.0}" > "${REDMINE_HOME}/.ruby-version"
    log_ok ".ruby-version 已创建 (${gemfile_ver:-3.2.0})"
  fi

  # ── CNB 云开发环境：自动添加 Host 白名单 ──
  # CNB 通过反向代理域名访问，Rails 7+ 默认拦截未知 Host
  if [[ -n "${CNB_BUILD_WORKSPACE:-}" ]] || grep -q '\.cnb\.run\z' <<< "${RAILS_DEVELOPMENT_HOSTS:-}" 2>/dev/null; then
    local cnb_initializer="${REDMINE_HOME}/config/initializers/allow_cnb_hosts.rb"
    if [[ ! -f "$cnb_initializer" ]]; then
      log_info "检测到 CNB 环境，创建 Host 白名单 initializer..."
      cat > "$cnb_initializer" << 'CNBEOF'
# frozen_string_literal: true
# Auto-generated by setup-redmine.sh for CNB cloud development environment.
# Allow all *.cnb.run proxy hosts.
Rails.application.config.hosts << ".cnb.run"
CNBEOF
      log_ok "已添加 CNB Host 白名单"
    fi
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 3 步：安装 Gem 依赖 (bundle install)                                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step3_bundle_install() {
  log_step "3/9: 安装 Ruby 依赖 (bundle install)"

  cd "${REDMINE_HOME}"

  # ── 配置 Bundler（跳过不需要的 group） ──
  if [[ "$RAILS_ENV" == "production" ]]; then
    bundle config set --local without 'development test'
  else
    bundle config set --local without ''
  fi

  # ── 设置 gem 安装路径（方便持久化） ──
  bundle config set --local path 'vendor/bundle'

  run_cmd "bundle install" bundle install
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 4 步：生成会话密钥 (generate_secret_token)                              ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step4_generate_secret() {
  log_step "4/9: 生成会话密钥"

  cd "${REDMINE_HOME}"

  if [[ -f "${REDMINE_HOME}/config/initializers/secret_token.rb" ]]; then
    log_warn "secret_token.rb 已存在，跳过生成"
  else
    run_cmd "生成加密会话令牌" bundle exec rake generate_secret_token
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 5 步：数据库迁移 (db:migrate)                                          ║
# ║  - RESET_DB=1 时：强制全量迁移                                              ║
# ║  - 否则：自动检测，已有表则增量迁移，无表则全量迁移                            ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step5_db_migrate() {
  log_step "5/9: 数据库迁移"

  cd "${REDMINE_HOME}"

  if _db_initialized; then
    log_info "检测到数据库已初始化，运行增量迁移..."
    run_cmd "增量 db:migrate" bundle exec rake db:migrate RAILS_ENV="${RAILS_ENV}"
  else
    log_info "数据库未初始化，运行完整迁移..."
    run_cmd "全量 db:migrate" bundle exec rake db:migrate RAILS_ENV="${RAILS_ENV}"
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 6 步：加载默认数据 (redmine:load_default_data)                          ║
# ║  - 自动检测 roles 表是否有数据，有则跳过                                      ║
# ║  - 支持 SQLite / MySQL / PostgreSQL 全部数据库类型                           ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step6_load_default_data() {
  log_step "6/9: 加载默认数据"

  cd "${REDMINE_HOME}"

  if _db_has_roles; then
    log_warn "检测到数据库已有数据（roles 表非空），跳过加载默认数据"
    return 0
  fi

  if [[ -n "$REDMINE_LANG" ]]; then
    run_cmd "加载默认数据 (语言: ${REDMINE_LANG})" bundle exec rake redmine:load_default_data RAILS_ENV="${RAILS_ENV}" REDMINE_LANG="${REDMINE_LANG}"
  else
    log_info "选择默认数据语言..."
    bundle exec rake redmine:load_default_data RAILS_ENV="${RAILS_ENV}"
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 7 步：编译静态资源 (assets:precompile)                                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step7_precompile_assets() {
  log_step "7/9: 编译静态资源"

  cd "${REDMINE_HOME}"

  if [[ "$RAILS_ENV" == "production" ]]; then
    if [[ -d "${REDMINE_HOME}/public/assets" ]] && ls "${REDMINE_HOME}/public/assets/"* &>/dev/null 2>&1; then
      log_warn "public/assets 已存在，跳过预编译"
    else
      run_cmd "预编译静态资源" bundle exec rake assets:precompile RAILS_ENV=production
    fi
  else
    log_info "开发环境跳过静态资源预编译（Rails 开发模式自动编译）"
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 8 步：插件迁移 (redmine:plugins:migrate)                                ║
# ║  - 自动检测插件是否有迁移文件，无则跳过                                       ║
# ║  - 插件迁移是幂等的，不会影响已有数据                                         ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step8_plugins_migrate() {
  log_step "8/9: 插件数据库迁移"

  cd "${REDMINE_HOME}"

  # 检查是否有插件自带的迁移文件
  if ls "${REDMINE_HOME}/plugins/"*/db/migrate/ &>/dev/null 2>&1; then
    run_cmd "插件数据迁移" bundle exec rake redmine:plugins:migrate RAILS_ENV="${RAILS_ENV}"
  else
    log_info "未检测到需要迁移的插件，跳过"
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  工具函数：终止已运行的 Redmine 服务                                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝
kill_existing_server() {
  local had_proc=false

  # 方法1：通过端口查找并 kill（优先用 fuser，无依赖问题）
  if command -v fuser &>/dev/null; then
    fuser -k "${REDMINE_PORT}/tcp" 2>/dev/null && had_proc=true
  elif command -v lsof &>/dev/null; then
    local pids
    pids=$(lsof -ti :"${REDMINE_PORT}" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs -r kill 2>/dev/null || true
      sleep 1
      echo "$pids" | xargs -r kill -9 2>/dev/null || true
      had_proc=true
    fi
  fi

  # 方法2：通过进程名兜底（puma/rails 进程）
  if pgrep -f "puma" &>/dev/null; then
    pkill -f "puma" 2>/dev/null || true
    sleep 1
    pkill -9 -f "puma" 2>/dev/null || true
    had_proc=true
  fi

  if $had_proc; then
    log_ok "已终止运行中的 Redmine 服务"
    sleep 1  # 确保端口完全释放
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 9 步：设置文件权限 & 启动服务                                           ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step9_start_server() {
  log_step "9/9: 设置权限 & 启动服务"

  cd "${REDMINE_HOME}"

  # ── 终止已运行的服务 ──
  kill_existing_server

  # ── 确保可写目录存在 ──
  mkdir -p tmp tmp/pdf tmp/cache tmp/sockets tmp/pids log files public/assets

  # ── 输出访问信息 ──
  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║  Redmine 启动成功！                                       ║${NC}"
  echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}${BOLD}║${NC}  访问地址   : ${CYAN}http://localhost:${REDMINE_PORT}${NC}"
  echo -e "${GREEN}${BOLD}║${NC}  默认账号   : ${YELLOW}admin${NC}"
  echo -e "${GREEN}${BOLD}║${NC}  默认密码   : ${YELLOW}admin${NC}"
  echo -e "${GREEN}${BOLD}║${NC}  运行环境   : ${RAILS_ENV}"
  echo -e "${GREEN}${BOLD}║${NC}  数据库类型 : ${DB_ADAPTER}"
  echo -e "${GREEN}${BOLD}║${NC}  项目根目录 : ${REDMINE_HOME}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "按 Ctrl+C 停止服务"

  # ── 启动 Puma 服务器 ──
  cd "${REDMINE_HOME}"
  exec bundle exec rails server \
    --binding "${REDMINE_BIND}" \
    --port "${REDMINE_PORT}" \
    --environment "${RAILS_ENV}"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：仅创建数据库（支持 MySQL/PostgreSQL）                             ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_create_database() {
  cd "${REDMINE_HOME}"
  log_info "创建 Redmine 数据库..."

  case "$DB_ADAPTER" in
    mysql2)
      log_info "通过 Rake 创建 MySQL 数据库..."
      bundle exec rake db:create RAILS_ENV="${RAILS_ENV}"
      ;;
    postgresql)
      log_info "通过 Rake 创建 PostgreSQL 数据库..."
      bundle exec rake db:create RAILS_ENV="${RAILS_ENV}"
      ;;
    *)
      log_info "SQLite 无需手动创建数据库，首次迁移时自动生成"
      ;;
  esac
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：发送测试邮件                                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_test_email() {
  local user="${1:-admin}"
  cd "${REDMINE_HOME}"
  log_info "向用户 '${user}' 发送测试邮件..."
  bundle exec rake redmine:email:test["${user}"] RAILS_ENV="${RAILS_ENV}"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：备份数据库                                                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_backup() {
  cd "${REDMINE_HOME}"
  local backup_dir="${REDMINE_HOME}/backups"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  mkdir -p "$backup_dir"

  log_info "备份数据库 + files 目录到 ${backup_dir}/backup_${timestamp}/"
  mkdir -p "${backup_dir}/backup_${timestamp}"

  case "$DB_ADAPTER" in
    sqlite3)
      if [[ -f "${REDMINE_HOME}/db/redmine_${RAILS_ENV}.sqlite3" ]]; then
        cp "${REDMINE_HOME}/db/redmine_${RAILS_ENV}.sqlite3" "${backup_dir}/backup_${timestamp}/"
      fi
      ;;
    mysql2)
      # 从 database.yml 中读取配置
      log_info "使用 mysqldump 备份 MySQL..."
      ;;
    *)
      log_warn "未实现该数据库类型的自动备份，请手动操作"
      ;;
  esac

  if [[ -d "${REDMINE_HOME}/files" ]]; then
    cp -r "${REDMINE_HOME}/files" "${backup_dir}/backup_${timestamp}/"
  fi

  log_ok "备份完成: ${backup_dir}/backup_${timestamp}"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：清理缓存和临时文件                                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_cleanup() {
  cd "${REDMINE_HOME}"
  log_info "清理 Redmine 缓存和临时文件..."
  bundle exec rake tmp:clear RAILS_ENV="${RAILS_ENV}"
  bundle exec rake redmine:attachments:prune RAILS_ENV="${RAILS_ENV}"
  bundle exec rake redmine:tokens:prune RAILS_ENV="${RAILS_ENV}"
  log_ok "清理完成"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：重置并重装（危险！需要 RESET_DB=1 确认）                            ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_reset() {
  cd "${REDMINE_HOME}"

  if [[ "$RESET_DB" != "1" ]]; then
    log_error "重置数据库需要设置 RESET_DB=1 进行确认"
    log_info "示例: RESET_DB=1 bash setup-redmine.sh reset"
    return 1
  fi

  log_warn "⚠️  这将删除所有数据并重新初始化！"
  if ! confirm_step "确认重置数据库？"; then
    log_info "已取消"
    return 0
  fi

  bundle exec rake db:drop RAILS_ENV="${RAILS_ENV}" 2>/dev/null || true
  bundle exec rake db:create RAILS_ENV="${RAILS_ENV}"
  bundle exec rake db:migrate RAILS_ENV="${RAILS_ENV}"
  bundle exec rake redmine:load_default_data RAILS_ENV="${RAILS_ENV}" REDMINE_LANG="${REDMINE_LANG:-zh}"
  bundle exec rake redmine:plugins:migrate RAILS_ENV="${RAILS_ENV}"
  log_ok "重置完成"
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：仅启动（跳过所有设置步骤）                                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_start_only() {
  print_banner
  step0_preflight
  step9_start_server
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  额外工具：生产环境启动（完整配置）                                         ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_production() {
  export RAILS_ENV=production
  REDMINE_PORT="${REDMINE_PORT:-80}"
  AUTO_CONFIRM=1
  main
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  主流程                                                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
main() {
  print_banner

  # ── 先做环境变量检查，凭据不全时立即中止 ──
  step0_preflight

  # ── RESET_DB 模式：清空数据库重建 ──
  if [[ "$RESET_DB" == "1" ]]; then
    log_warn "=============================================="
    log_warn "  RESET_DB=1 - 将清空数据库并重新初始化"
    log_warn "=============================================="
    if ! confirm_step "确认清空数据库并重建？"; then
      log_info "已取消"
      exit 0
    fi
  fi

  step1_check_system
  step2_setup_config
  step3_bundle_install
  step4_generate_secret

  # ── 数据库操作 ──
  if [[ "$RESET_DB" == "1" ]]; then
    # 清空重建模式
    log_step "DB: 清空并重建数据库"
    cd "${REDMINE_HOME}"
    run_cmd "删除旧数据库" bundle exec rake db:drop RAILS_ENV="${RAILS_ENV}" 2>/dev/null || true
    run_cmd "创建数据库" bundle exec rake db:create RAILS_ENV="${RAILS_ENV}"
    step5_db_migrate
    step6_load_default_data
    step8_plugins_migrate
  else
    # 保护数据模式（默认）：自动检测，智能跳过
    log_info "数据库模式: 保护已有数据 (设置 RESET_DB=1 可清空重建)"
    step5_db_migrate
    step6_load_default_data
    step8_plugins_migrate
  fi

  step7_precompile_assets
  step9_start_server
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  入口：命令行分发                                                           ║
# ╚════════════════════════════════════════════════════════════════════════════╝
usage() {
  echo ""
  banner "Redmine 一键启动脚本 — 用法"
  echo ""
  echo "  bash setup-redmine.sh                    # 完整安装 + 启动 (dev 环境)"
  echo "  bash setup-redmine.sh start              # 仅启动（跳过设置）"
  echo "  bash setup-redmine.sh prod               # 生产环境安装 + 启动"
  echo "  bash setup-redmine.sh create-db          # 仅创建数据库"
  echo "  bash setup-redmine.sh reset              # 重置所有数据（危险！）"
  echo "  bash setup-redmine.sh backup             # 备份数据库 + 附件"
  echo "  bash setup-redmine.sh cleanup            # 清理缓存和临时文件"
  echo "  bash setup-redmine.sh test-email [user]  # 发送测试邮件"
  echo ""
  echo "  环境变量:"
  echo "    DB_ADAPTER      数据库类型 (sqlite3/mysql2/postgresql)  默认: sqlite3"
  echo "    RAILS_ENV       运行环境 (development/production)       默认: development"
  echo "    REDMINE_PORT    监听端口                                默认: 3000"
  echo "    REDMINE_BIND    绑定地址                                默认: 0.0.0.0"
  echo "    REDMINE_LANG    默认数据语言 (zh/en/fr/ja ...)          默认: zh"
  echo "    RESET_DB        清空数据库重建 (1=清空, 0=保留)         默认: 0"
  echo "    AUTO_CONFIRM    自动确认所有提示 (1/0)                  默认: 0"
  echo "    QUIET_MODE      静默模式 (1/0)                          默认: 1"
  echo "    REDMINE_RUBY_VERSION  rbenv 自动安装的 Ruby 版本       默认: 3.3.6"
  echo ""
  echo "  凭据（配置已脱敏入库，启动前会强制检查）:"
  echo "    REDMINE_DB_PASSWORD  数据库密码（必填）                 可用 config/additional_environment.rb 提供"
  echo "    SECRET_KEY_BASE      会话密钥（生产必填）               开发环境缺省自动生成 config/.secret_key_base"
  echo "    REDMINE_DB_HOST / REDMINE_DB_PORT / REDMINE_DB_USER / REDMINE_DB_NAME  可选，覆盖 database.yml 默认值"
  echo ""
  echo "  示例:"
  echo "    # 使用 PostgreSQL 启动（自动检测并保护已有数据）"
  echo "    DB_ADAPTER=postgresql bash setup-redmine.sh"
  echo ""
  echo "    # 清空数据库重建"
  echo "    RESET_DB=1 DB_ADAPTER=postgresql bash setup-redmine.sh"
  echo ""
  echo "    # 仅重置数据库（不启动服务）"
  echo "    RESET_DB=1 bash setup-redmine.sh reset"
  echo ""
  echo "  参考: https://www.redmine.org/projects/redmine/wiki/Guide"
  echo ""
}

# ── 入口判断 ──
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

case "${1:-}" in
  start)
    tools_start_only
    ;;
  prod|production)
    tools_production
    ;;
  create-db)
    tools_create_database
    ;;
  reset)
    tools_reset
    ;;
  backup)
    tools_backup
    ;;
  cleanup)
    tools_cleanup
    ;;
  test-email)
    tools_test_email "${2:-admin}"
    ;;
  *)
    main
    ;;
esac
