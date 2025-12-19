# Emerge 电商 Demo（Saleor + Next.js）

本项目基于 Saleor（API + Dashboard）与 Next.js Storefront，提供一键本地/测试环境部署脚本与 GitLab CI 方案。

- 后端与中间件：Saleor API、Dashboard、Postgres、Redis、Mailpit、Jaeger
- 前台：Next.js Storefront（已适配站点名“emerge”，可通过环境变量覆盖）

## 目录结构
- `saleor-platform/`：Saleor 本地开发编排（Compose）
- `react-storefront/`：Next.js Storefront 前台
- `scripts/`：脚本
  - `scripts/deploy.sh`：一键本地/服务器部署
  - `scripts/remote_deploy.sh`：本机通过 SSH 将代码同步到远端并执行部署
 - `docs/`：对外文档（产品/业务/API）
   - `docs/Product.md`、`docs/Business.md`、`docs/API.md`

## 前置条件
- Docker 27+、Docker Compose v2
- Docker Desktop（macOS/Windows）内存建议 ≥ 5GB

## 一键本地部署
在仓库根目录执行（可直接复制）：

```
SITE_NAME=emerge API_PORT=8001 DASHBOARD_PORT=9001 STOREFRONT_PORT=3000 \
ADMIN_EMAIL=328951525@qq.com ADMIN_PASSWORD='ww19880422.' \
bash scripts/deploy.sh
```

完成后访问：
- 前台：`http://localhost:3000`
- 后台：`http://localhost:9001`
- GraphQL：`http://localhost:8001/graphql/`
- Mailpit：`http://localhost:8025`
- Jaeger：`http://localhost:16686`

默认后台管理员：
- 邮箱：`328951525@qq.com`
- 密码：`ww19880422.`

说明：`scripts/deploy.sh` 会自动迁移数据库、导入示例数据、创建/更新管理员，并把站点域名设置为 `host.docker.internal:API_PORT` 以保证图片地址可用；同时写入前台 `.env` 并启动前台容器。

## 远程部署到测试环境（三选一）

1) GitLab CI（推荐）
- 在仓库 CI 变量中配置：
  - 必填：`DEPLOY_SSH_HOST`、`DEPLOY_SSH_USER`、`SSH_PRIVATE_KEY`
  - 可选：`DEPLOY_SSH_PORT=22`、`DEPLOY_PATH=/opt/e_shop`
  - 可选：`API_PORT=8001`、`DASHBOARD_PORT=9001`、`STOREFRONT_PORT=3000`
  - 可选：`ADMIN_EMAIL`、`ADMIN_PASSWORD`、`SITE_NAME`（默认 emerge）
- 运行 Job `deploy_test`（分支 test 自动触发，main 为手动）。
- 成功后访问：`http://<DEPLOY_SSH_HOST>:3000`（前台），`http://<DEPLOY_SSH_HOST>:9001`（后台）。

2) 本机通过 SSH 远程部署
```
DEPLOY_SSH_HOST=43.199.1.126 DEPLOY_SSH_USER=root SITE_NAME=emerge \
ADMIN_EMAIL=328951525@qq.com ADMIN_PASSWORD='ww19880422.' \
./scripts/remote_deploy.sh
```
- 首次会把代码同步到远端（默认 `/opt/e_shop`），然后执行 `scripts/deploy.sh`。

3) 在测试机手动部署
```
# 在测试机上执行
git clone http://43.199.1.126:9099/kaka36547/e_shop.git /opt/e_shop
cd /opt/e_shop
SITE_NAME=emerge API_PORT=8001 DASHBOARD_PORT=9001 STOREFRONT_PORT=3000 \
ADMIN_EMAIL=328951525@qq.com ADMIN_PASSWORD='ww19880422.' \
bash scripts/deploy.sh
```

## 常用命令
- 查看状态：
  - 后端：`cd saleor-platform && docker compose ps`
  - 前台：`cd react-storefront && docker compose ps`
- 查看日志：
  - API：`cd saleor-platform && docker compose logs -f api`
  - Dashboard：`cd saleor-platform && docker compose logs -f dashboard`
  - 前台：`cd react-storefront && docker compose logs -f`
- 停止服务：
  - `cd saleor-platform && docker compose stop && cd ../react-storefront && docker compose down`
- 干净重装（清空数据卷）：
  - `cd react-storefront && docker compose down -v`
  - `cd ../saleor-platform && docker compose down --volumes`
  - 重新执行部署脚本

## 配置项（环境变量）
- `SITE_NAME`：站点名称（默认 `emerge`）
- `ADMIN_EMAIL`、`ADMIN_PASSWORD`：后台管理员账号
- `API_PORT`、`DASHBOARD_PORT`、`STOREFRONT_PORT`：暴露端口
- `SALEOR_DIR`、`STOREFRONT_DIR`：目录名（默认 `saleor-platform`、`react-storefront`）
- 远程部署：`DEPLOY_SSH_HOST`、`DEPLOY_SSH_USER`、`DEPLOY_SSH_PORT`、`DEPLOY_PATH`、`SSH_PRIVATE_KEY`

## 常见问题与排查
- Dashboard 登录报错（Login went wrong）
  - 原因：Dashboard 指向了错的 API（常见为 `http://localhost:8000/graphql/`）。已在编排中固定到 8001。
  - 仍异常时：在登录页齿轮按钮里把 API URL 改为 `http://localhost:8001/graphql/`；或在浏览器 Console 输入：
    - `localStorage.setItem('dashboardAPIUrl','http://localhost:8001/graphql/'); location.reload();`
- 前台图片不显示
  - 已通过前台代码把 `/thumbnail` 与 `/media` 地址统一到 API 域名；后端也设置 `ALLOWED_HOSTS=...,host.docker.internal` 与 Site 域名。
  - 如仍异常，清缓存后重试（Cmd/Ctrl+Shift+R）。
- 端口占用
  - 替换 `API_PORT/DASHBOARD_PORT/STOREFRONT_PORT` 为空闲端口重新部署。
- Linux 上访问宿主机
  - 前台 Compose 已添加 `extra_hosts: host.docker.internal:host-gateway`，确保容器可访问宿主机 `API_PORT`。

## 参考
- 本地部署脚本：`scripts/deploy.sh`
- 远程部署脚本：`scripts/remote_deploy.sh`
- GitLab CI：`.gitlab-ci.yml`
