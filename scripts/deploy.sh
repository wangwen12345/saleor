#!/usr/bin/env bash
SITE_NAME=saleor 
API_PORT=8001 
DASHBOARD_PORT=9001 
STOREFRONT_PORT=3000
ALLOWED_HOSTS_EXTRA="47.76.215.70"
ADMIN_EMAIL=328951525@qq.com 
ADMIN_PASSWORD='ww19880422.'
ALLOWED_HOSTS=='47.76.215.70'
set -Eeuo pipefail

# 一键本地部署脚本（Saleor 后端 API + Dashboard + Next.js 前台）
# 说明：
# - 依赖 Docker 与 Docker Compose v2；macOS/Windows 推荐使用 Docker Desktop。
# - 首次运行会拉取镜像、初始化数据库并导入示例数据。
# - 会自动创建/更新管理员账号（见下方环境变量）。
# - 默认端口：API 8001、Dashboard 9001、前台 3000，可通过环境变量覆盖。
#
# 使用示例：
#   API_PORT=8001 DASHBOARD_PORT=9001 STOREFRONT_PORT=3000 \
#   ADMIN_EMAIL=admin@gmail.com ADMIN_PASSWORD='你的密码' \
#   SITE_NAME=emerge bash scripts/deploy.sh
#
# 常见问题：
# - 端口被占用：修改上述端口变量为未占用端口。
# - Linux 环境访问 API：脚本已处理 host.docker.internal（如仍有问题可改为容器内网互通方案）。

# 管理员邮箱
ADMIN_EMAIL=${ADMIN_EMAIL:-328951525@qq.com}
# 管理员密码
ADMIN_PASSWORD=${ADMIN_PASSWORD:-ww19880422.}
# 站点名称（前后端展示）
SITE_NAME=${SITE_NAME:-saleor}
# 额外允许访问的主机名/IP（逗号分隔），如："47.76.215.70,example.com"
ALLOWED_HOSTS_EXTRA=${ALLOWED_HOSTS_EXTRA:-}

# 后端平台目录
SALEOR_DIR=${SALEOR_DIR:-saleor-platform}
# 前台目录
STOREFRONT_DIR=${STOREFRONT_DIR:-react-storefront}

# API 对外端口
API_PORT=${API_PORT:-8001}
# Dashboard 对外端口
DASHBOARD_PORT=${DASHBOARD_PORT:-9001}
# 前台对外端口
STOREFRONT_PORT=${STOREFRONT_PORT:-3000}

# 前台访问 API 的 GraphQL 地址（容器访问宿主机）
API_GRAPHQL="http://host.docker.internal:${API_PORT}/graphql/"
# 允许的基础主机列表
ALLOWED_HOSTS_BASE="localhost,api,host.docker.internal"
# 合并额外主机
if [ -n "${ALLOWED_HOSTS_EXTRA}" ]; then
  ALLOWED_HOSTS_FULL="${ALLOWED_HOSTS_BASE},${ALLOWED_HOSTS_EXTRA}"
else
  ALLOWED_HOSTS_FULL="${ALLOWED_HOSTS_BASE}"
fi
# Django Site 域名（用于图片绝对地址）：优先选用 ALLOWED_HOSTS_EXTRA 的第一个项
SITE_DOMAIN="host.docker.internal:${API_PORT}"
if [ -n "${ALLOWED_HOSTS_EXTRA}" ]; then
  FIRST_EXTRA=$(printf "%s" "${ALLOWED_HOSTS_EXTRA}" | tr ' ,' '\n\n' | sed -n '1p')
  if [ -n "${FIRST_EXTRA}" ]; then
    case "${FIRST_EXTRA}" in
      *:*) SITE_DOMAIN="${FIRST_EXTRA}" ;;
      *)   SITE_DOMAIN="${FIRST_EXTRA}:${API_PORT}" ;;
    esac
  fi
fi

info() { printf "\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }
}

need docker
need git

ROOT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

info "克隆/准备 Saleor 平台代码（如已存在则跳过）"
if [ ! -d "$SALEOR_DIR" ]; then
  git clone --depth 1 https://github.com/saleor/saleor-platform.git "$SALEOR_DIR"
fi

info "写入 docker-compose.override.yml（端口与环境变量覆盖）"
cat >"$SALEOR_DIR/docker-compose.override.yml" <<EOF
services:
  api:
    ports:
      - "${API_PORT}:8000"
    environment:
      - DASHBOARD_URL=http://47.76.215.70:${DASHBOARD_PORT}/
      - ALLOWED_HOSTS=${ALLOWED_HOSTS_FULL}
  dashboard:
    ports:
      - "${DASHBOARD_PORT}:80"
    environment:
      - API_URL=http://47.76.215.70:${API_PORT}/graphql/
  # keep DB/Redis internal to avoid host port conflicts
  db:
    ports: []
  redis:
    ports: []
EOF

info "启动基础服务：Postgres / Redis / Jaeger / Mailpit"
(cd "$SALEOR_DIR" && docker compose up -d db redis jaeger mailpit)

info "等待 Postgres 就绪"
ATTEMPTS=120
until (cd "$SALEOR_DIR" && docker compose exec -T db pg_isready -U saleor >/dev/null 2>&1); do
  ATTEMPTS=$((ATTEMPTS-1))
  if [ $ATTEMPTS -le 0 ]; then err "Postgres not ready in time"; exit 1; fi
  sleep 1
done

info "执行数据库迁移"
(cd "$SALEOR_DIR" && docker compose run --rm api python3 manage.py migrate)

info "导入示例数据（包含演示商品等）"
(cd "$SALEOR_DIR" && docker compose run --rm api python3 manage.py populatedb --createsuperuser || true)

info "创建/更新管理员账号：${ADMIN_EMAIL}"
(cd "$SALEOR_DIR" && docker compose run --rm api bash -lc "python3 manage.py shell -c \"from django.contrib.auth import get_user_model; U=get_user_model(); u,created=U.objects.get_or_create(email='${ADMIN_EMAIL}', defaults={'is_staff':True,'is_superuser':True,'first_name':'Admin'}); u.is_active=True; u.is_staff=True; u.is_superuser=True; u.set_password('${ADMIN_PASSWORD}'); u.save(); print('Admin ready:', u.email)\"")

info "设置站点域名/名称与站点参数（Site & SiteSettings）"
(cd "$SALEOR_DIR" && docker compose run --rm api bash -lc "python3 manage.py shell -c \"from django.contrib.sites.models import Site; from saleor.site.models import SiteSettings; s,_=Site.objects.update_or_create(id=1, defaults={'domain':'${SITE_DOMAIN}','name':'${SITE_NAME}'}); ss=SiteSettings.objects.get(site_id=s.id); ss.header_text='${SITE_NAME}'; ss.default_mail_sender_name='${SITE_NAME}'; ss.save(update_fields=['header_text','default_mail_sender_name']); print('Site updated:', s.domain, s.name)\"")

info "启动 API、Dashboard 与 Worker 服务"
(cd "$SALEOR_DIR" && docker compose up -d api dashboard worker)

info "克隆/准备前台 Storefront 代码（如已存在则跳过）"
if [ ! -d "$STOREFRONT_DIR" ]; then
  git clone --depth 1 https://github.com/saleor/react-storefront.git "$STOREFRONT_DIR"
fi

info "写入前台 .env 配置（API 地址、前台 URL、站点名）"
cat >"$STOREFRONT_DIR/.env" <<EOF
NEXT_PUBLIC_SALEOR_API_URL=${API_GRAPHQL}
NEXT_PUBLIC_STOREFRONT_URL=http://47.76.215.70:${STOREFRONT_PORT}
NEXT_PUBLIC_SITE_NAME=${SITE_NAME}
# GraphQL Codegen 在构建阶段使用的 Schema 地址（构建容器通过 host-gateway 访问本机 API）
CODEGEN_SCHEMA_URL=${API_GRAPHQL}
EOF

info "构建并启动前台容器（首次耗时较长）"
(cd "$STOREFRONT_DIR" && docker compose up -d --build)

cat <<DONE

=== 部署完成（Deployment Complete）===
- 前台（Storefront）:   http://localhost:${STOREFRONT_PORT}
- 后台（Dashboard）:    http://localhost:${DASHBOARD_PORT}
- API GraphQL:         ${API_GRAPHQL}
- 邮件测试（Mailpit）:  http://localhost:8025
- APM（Jaeger）:        http://localhost:16686

管理员账号：
  邮箱（Email）：${ADMIN_EMAIL}
  密码（Password）：${ADMIN_PASSWORD}

常用操作：
- 停止： (cd ${SALEOR_DIR} && docker compose stop) && (cd ${STOREFRONT_DIR} && docker compose down)
- 重新设置管理员：修改环境变量后重新执行本脚本，或只设置 ADMIN_EMAIL/ADMIN_PASSWORD 再执行。

提示：首次构建前台镜像耗时较长，请耐心等待日志输出完成。
DONE
