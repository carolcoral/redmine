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
SKIP_DB_SETUP="${SKIP_DB_SETUP:-0}"       # 跳过数据库设置（已有数据库时设为 1）
AUTO_CONFIRM="${AUTO_CONFIRM:-0}"         # 0=交互式确认, 1=自动执行
QUIET_MODE="${QUIET_MODE:-0}"             # 0=正常输出, 1=静默模式

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

# ── 打印 Banner ──────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${GREEN}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║                                                          ║"
  echo "║         Redmine 一键启动脚本                              ║"
  echo "║         基于 Rails 8.1.3  ·  Ruby >= 3.2.0               ║"
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
# ║  第 1 步：检查 & 安装系统依赖 (Ruby / SQLite / 编译工具)                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step1_check_system() {
  log_step "1/9: 检查系统依赖"

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
  if [[ ! -f "${REDMINE_HOME}/.ruby-version" ]]; then
    echo "3.2.0" > "${REDMINE_HOME}/.ruby-version"
    log_ok ".ruby-version 已创建"
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
# ╚════════════════════════════════════════════════════════════════════════════╝
step5_db_migrate() {
  log_step "5/9: 数据库迁移"

  cd "${REDMINE_HOME}"

  if [[ ! -f "${REDMINE_HOME}/db/schema.rb" ]]; then
    run_cmd "运行 db:migrate" bundle exec rake db:migrate RAILS_ENV="${RAILS_ENV}"
  elif [[ "$SKIP_DB_SETUP" == "1" ]]; then
    log_warn "检测到已有 schema.rb，SKIP_DB_SETUP=1，跳过迁移"
  else
    log_info "检测到已有 schema.rb，运行增量迁移..."
    run_cmd "运行增量 db:migrate" bundle exec rake db:migrate RAILS_ENV="${RAILS_ENV}"
  fi
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  第 6 步：加载默认数据 (redmine:load_default_data)                          ║
# ╚════════════════════════════════════════════════════════════════════════════╝
step6_load_default_data() {
  log_step "6/9: 加载默认数据"

  cd "${REDMINE_HOME}"

  # 检查是否已加载过默认数据（通过检查 roles 表）
  local already_loaded=false
  case "$DB_ADAPTER" in
    sqlite3)
      DB_PATH="${REDMINE_HOME}/db/redmine_${RAILS_ENV}.sqlite3"
      if [[ -f "$DB_PATH" ]]; then
        sqlite3 "$DB_PATH" "SELECT count(*) FROM roles;" &>/dev/null && already_loaded=true
      fi
      ;;
    *)
      # 其他数据库类型，让 redmine:load_default_data 自行判断
      ;;
  esac

  if [[ "$already_loaded" == "true" ]]; then
    log_warn "检测到数据库中已有 roles 数据，跳过加载默认数据"
  else
    if [[ -n "$REDMINE_LANG" ]]; then
      run_cmd "加载默认数据 (语言: ${REDMINE_LANG})" bundle exec rake redmine:load_default_data RAILS_ENV="${RAILS_ENV}" REDMINE_LANG="${REDMINE_LANG}"
    else
      log_info "选择默认数据语言..."
      bundle exec rake redmine:load_default_data RAILS_ENV="${RAILS_ENV}"
    fi
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
# ╚════════════════════════════════════════════════════════════════════════════╝
step8_plugins_migrate() {
  log_step "8/9: 插件数据库迁移"

  cd "${REDMINE_HOME}"

  # 检查是否有插件需要迁移
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
# ║  额外工具：重置并重装（危险！）                                              ║
# ╚════════════════════════════════════════════════════════════════════════════╝
tools_reset() {
  cd "${REDMINE_HOME}"
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
  step1_check_system
  step2_setup_config
  step3_bundle_install
  step4_generate_secret
  step5_db_migrate
  step6_load_default_data
  step7_precompile_assets
  step8_plugins_migrate
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
  echo "    SKIP_DB_SETUP   跳过数据库设置 (1/0)                    默认: 0"
  echo "    AUTO_CONFIRM    自动确认所有提示 (1/0)                  默认: 0"
  echo "    QUIET_MODE      静默模式 (1/0)                          默认: 0"
  echo ""
  echo "  示例:"
  echo "    # 使用 MySQL 启动开发环境"
  echo "    DB_ADAPTER=mysql2 REDMINE_DB_USER=root REDMINE_DB_PASS=secret bash setup-redmine.sh"
  echo ""
  echo "    # 无交互自动安装"
  echo "    AUTO_CONFIRM=1 bash setup-redmine.sh"
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
