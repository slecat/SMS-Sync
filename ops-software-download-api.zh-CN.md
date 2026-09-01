# Ops Software Download 接口文档（中文）

更新时间: 2026-03-05  
服务目录: `/root/server/ops-software-download`  
默认地址: `http://127.0.0.1:8002`

## 1. 认证与响应约定

### 1.1 后台鉴权方式

后台接口（`/api/admin/*`）支持三种鉴权方式:

1. Bearer Token（`Authorization: Bearer <ADMIN_TOKEN>`）
2. Ops Console 会话 Cookie（通过 `/api/admin/auth/login` 建立或已有 `8000` 登录态）
3. Ops Console 服务 Key（`Authorization: Bearer <opsk_...>` 或 `X-Ops-Service-Key: <opsk_...>`）

### 1.2 通用响应结构

成功:

```json
{
  "success": true,
  "data": {}
}
```

失败:

```json
{
  "success": false,
  "error": "错误信息"
}
```

## 2. 接口总览

| 方法 | 路径 | 是否鉴权 | 说明 |
|---|---|---|---|
| GET | `/healthz` | 否 | 健康检查 |
| GET | `/readyz` | 否 | 就绪检查（DB + 存储） |
| GET | `/` | 否 | 首页 |
| GET | `/api/public/softwares` | 否 | 软件列表（含最新版本） |
| GET | `/api/public/softwares/:slug/icon` | 否 | 软件图标 |
| GET | `/api/public/softwares/:slug/releases` | 否 | 指定软件所有已发布版本 |
| GET | `/api/public/softwares/:slug/releases/latest` | 否 | 指定软件最新版本详情 |
| GET | `/api/public/download/:releaseId` | 否 | 按 releaseId 下载 |
| GET | `/api/public/download/:slug/latest` | 否 | 下载指定软件最新版本 |
| POST | `/api/admin/auth/login` | 否 | 使用 Ops Console 账号密码登录 |
| GET | `/api/admin/auth/me` | 否 | 查询当前后台身份 |
| POST | `/api/admin/auth/logout` | 否 | 退出后台会话 |
| GET | `/api/admin/softwares` | 是 | 软件列表（管理视角） |
| POST | `/api/admin/softwares` | 是 | 新建软件 |
| PATCH | `/api/admin/softwares/:id` | 是 | 更新软件信息 |
| POST | `/api/admin/softwares/:id/icon` | 是 | 更新软件图标 |
| POST | `/api/admin/softwares/upload` | 是 | 一次性上传“软件+图标+首个版本包”（`build_number` 可选，默认 `1`） |
| POST | `/api/admin/releases/upload` | 是 | 为已有软件上传新版本（`build_number` 必填） |
| GET | `/api/admin/releases` | 是 | 发布记录分页查询（包含 `build_number` 与下载源字段） |
| DELETE | `/api/admin/releases/:id` | 是 | 删除版本（可选保留文件） |

## 3. 基础检查接口

### 3.1 健康检查

`GET /healthz`

```json
{
  "success": true,
  "data": {
    "status": "ok"
  }
}
```

### 3.2 就绪检查

`GET /readyz`

返回字段:
- `success`: `true/false`
- `data.db`: SQLite 是否可用
- `data.storage`: 存储目录是否存在

当任一检查失败时返回 `503`。

## 4. 公开接口（无需登录）

### 4.1 软件列表

`GET /api/public/softwares`

返回:
- 软件基本信息
- `latestRelease`（若有发布）

### 4.2 图标

`GET /api/public/softwares/:slug/icon`

说明:
- 找不到软件或图标文件时返回 `404`。
- 返回文件流而非 JSON。

### 4.3 指定软件全部已发布版本

`GET /api/public/softwares/:slug/releases`

### 4.4 指定软件最新版本

`GET /api/public/softwares/:slug/releases/latest`

### 4.5 按版本 ID 下载

`GET /api/public/download/:releaseId`

行为:
- 若本地文件存在: 返回附件下载。
- 若本地文件不存在但配置了镜像地址: `302` 重定向到第一个镜像地址。
- 若均不可用: `404`。

### 4.6 下载某软件最新版本

`GET /api/public/download/:slug/latest`

行为:
- 若默认下载源为外链镜像: `302` 跳转镜像。
- 否则优先下载本地文件。
- 本地缺失时回退第一个镜像；仍不可用返回 `404`。

## 5. 后台认证接口

### 5.1 登录

`POST /api/admin/auth/login`

请求体:

```json
{
  "username": "admin",
  "password": "******"
}
```

返回:
- `data.username`
- `data.token`（即 `ADMIN_TOKEN`，用于 Bearer 方式）

说明:
- 若上游 Ops Console 返回 `Set-Cookie`，本服务会透传。

### 5.2 当前身份

`GET /api/admin/auth/me`

说明:
- 当请求携带 Cookie、`Authorization` 或 `X-Ops-Service-Key` 时，服务会把这些鉴权头转发到 Ops Console `/api/auth/me` 做校验（同时保留本地 `ADMIN_TOKEN` 逻辑）。

返回示例:

```json
{
  "success": true,
  "data": {
    "username": "admin",
    "source": "ops-console-session"
  }
}
```

`source`:
- `token`（Bearer）
- `ops-console-session`（Cookie 会话）
- `ops-console-service-key`（服务 Key）

### 5.3 退出

`POST /api/admin/auth/logout`

行为:
- 若请求带 Cookie，会尝试转发到 Ops Console 登出并透传清理 Cookie。
- 无论上游是否可达，接口都返回 `success: true`。

## 6. 后台软件管理接口（需鉴权）

### 6.1 软件列表

`GET /api/admin/softwares`

### 6.2 新建软件

`POST /api/admin/softwares`

请求体:

```json
{
  "slug": "sms-sync",
  "name": "SMS Sync",
  "description": "optional",
  "platforms": "android"
}
```

约束:
- `slug`、`name` 必填
- `slug` 必须是小写 kebab-case
- `platforms` 可选，若提供必须是: `windows` / `android` / `ios`
- `name` 与 `slug` 均需唯一（忽略大小写 name 冲突）

### 6.3 更新软件信息

`PATCH /api/admin/softwares/:id`

可更新字段:
- `name`
- `description`
- `platforms`

约束:
- 至少提供一个字段
- `name` 不能为空
- `platforms` 若提供需合法

### 6.4 更新图标

`POST /api/admin/softwares/:id/icon`

Content-Type: `multipart/form-data`  
文件字段:
- `icon`

允许后缀:
- `.png`, `.jpg`, `.jpeg`, `.webp`, `.svg`, `.ico`

## 7. 后台发布管理接口（需鉴权）

### 7.1 一次性上传软件与首发版本

`POST /api/admin/softwares/upload`

Content-Type: `multipart/form-data`

文件字段:
- `icon`（必填）
- `file`（安装包，必填）

表单字段:
- `name`（必填）
- `platforms`（必填，`windows|android|ios`）
- `version`（必填，严格 semver）
- `build_number`（可选，正整数，默认 `1`）
- `description`（可选）
- `slug`（可选，不传则由 name 生成）
- `download_urls`（可选，逗号/换行分隔镜像 URL）
- `default_download_source`（可选，`local` 或某个镜像 URL）

安装包允许后缀:
- `.apk`, `.ipa`, `.exe`, `.msi`, `.dmg`, `.pkg`, `.deb`, `.rpm`, `.jar`, `.aab`, `.zip`, `.tar`, `.gz`, `.7z`, `.rar`, `.appimage`, `.msix`

### 7.2 为已有软件上传新版本

`POST /api/admin/releases/upload`

Content-Type: `multipart/form-data`

文件字段:
- `file`（必填）

表单字段:
- `software_id`（必填，正整数）
- `version`（必填，严格 semver）
- `build_number`（必填，正整数）
- `changelog`（可选）
- `download_urls`（可选）
- `default_download_source`（可选）

唯一性约束:
- `UNIQUE(software_id, version, build_number)`
- 同一 `version` 允许多个不同 `build_number`

### 7.3 发布记录分页

`GET /api/admin/releases?page=1&pageSize=20&software_id=1`

参数:
- `page` 默认 `1`
- `pageSize` 默认 `20`，最大 `100`
- `software_id` 可选，传入时必须为正整数

返回:
- `items`
- `page`
- `pageSize`
- `total`
- `totalPages`

`items[]` 关键字段:
- `version`
- `build_number`
- `download_url`（默认下载地址）
- `download_urls`（镜像地址数组）
- `download_sources`（`local` + 镜像地址明细）

### 7.4 删除发布记录

`DELETE /api/admin/releases/:id?deleteFile=false`

参数:
- `id` 必填，正整数
- `deleteFile` 可选，默认删除安装包文件；传 `false` 时只删数据库记录

返回:
- `id`
- `deletedFile`

## 8. 常见错误

- `400` 参数错误（如版本号非法、后缀不支持、ID 非法）
- `401` 未认证
- `404` 软件/版本/文件不存在
- `409` 唯一键冲突（重名软件、重复 `(software_id, version, build_number)`）
- `500` 服务内部错误
- `502` Ops Console 上游不可用（认证链路）
