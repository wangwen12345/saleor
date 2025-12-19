# 故障排查 · Emerge 电商 Demo

## 1. Dashboard 登录失败
- 现象：提示 “Login went wrong”，Network 显示请求到 `http://localhost:8000/graphql/`
- 处理：
  - 登录页齿轮设置 API URL 为 `http://localhost:8001/graphql/`
  - 或执行：`localStorage.setItem('dashboardAPIUrl','http://localhost:8001/graphql/'); location.reload();`

## 2. 图片不显示
- 检查：
  - API 环境变量 `ALLOWED_HOSTS` 包含 `host.docker.internal`
  - Django `django_site.domain` 是否为 `host.docker.internal:8001`
  - 前台 `.env` 的 `NEXT_PUBLIC_SALEOR_API_URL` 是否为 `http://host.docker.internal:8001/graphql/`
- 强制刷新浏览器缓存（Cmd/Ctrl+Shift+R）

## 3. 端口被占用
- 改用其它端口：`API_PORT/DASHBOARD_PORT/STOREFRONT_PORT`
- 更新后重新执行 `scripts/deploy.sh`

## 4. 数据库迁移异常
- 执行：`cd saleor-platform && docker compose run --rm api python3 manage.py migrate`
- 若需要清库重装：`docker compose down --volumes`

## 5. 网络问题（Linux）
- `host.docker.internal` 解析异常：在前台 compose 中已添加 `extra_hosts: host-gateway`；如仍失败，可改为 API 容器内网服务名直连（需要改前台配置）

## 6. 构建阶段 Codegen 无法加载 Schema（host.docker.internal ENOTFOUND）
- 现象：`graphql-codegen` 报错 `getaddrinfo ENOTFOUND host.docker.internal`
- 原因：在 Linux 构建容器中无法解析宿主名。
- 处理：
  - 已在 `.graphqlrc.ts` 增加 `CODEGEN_SCHEMA_URL` 优先级；
  - 部署脚本会在 `react-storefront/.env` 写入 `CODEGEN_SCHEMA_URL=https://demo.saleor.io/graphql/`，仅用于构建阶段类型生成；
  - 运行时仍使用 `NEXT_PUBLIC_SALEOR_API_URL`（指向你的 API），不受影响。
