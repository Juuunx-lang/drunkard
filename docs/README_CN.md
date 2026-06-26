# Drunkard 中文项目总手册

Drunkard 是一个面向私人酒局、小型聚会、家庭吧台和调酒师点单场景的应用。它不是单纯展示酒单的小网页，而是一套包含顾客点单、调酒师接单、库存提示、订单实时同步、评价、社区和后台维护能力的小型酒馆系统。

当前稳定上线版由三部分组成：

- **Flutter 客户端**：支持 Web 和 Android APK。
- **Node.js 后端**：提供登录注册、酒单、订单、评论、社区、上传、后台管理等接口。
- **PostgreSQL 数据库**：保存用户、酒品、分类、库存、订单、评论、社区内容等数据。

部署方式采用 Docker Compose，服务器上由 Nginx 容器提供静态资源、接口反代和上传图片访问。

## 适合的使用场景

适合：

- 家庭酒吧、朋友聚会、小型私人酒局。
- 有一个调酒师或主理人负责接单和制作。
- 顾客希望用手机扫码或打开链接点酒。
- 调酒师希望看到订单、缺料、评价和历史记录。
- 项目所有者希望后续继续扩展社区、会员、酒单和运营功能。

不适合：

- 大型商业酒吧高并发收银系统。
- 强支付、强财务、强库存核算系统。
- 需要 iOS Safari 原生级 60fps 动画体验的场景。

## 当前最终上线版状态

当前稳定版采用普通 Flutter Web JS 构建。

已经验证过：

- Web 主站可通过服务器端口访问。
- Android APK 可连接服务器 API。
- Docker Compose 可以启动后端、数据库和 Nginx。
- `/api/health` 健康检查正常。
- `/wasm/` 灰度性能实验已撤掉，因为对 iPhone Safari 帧率没有明显改善。
- iOS Safari 左缘系统返回手势存在浏览器层限制，最终不再做额外拦截，避免影响正常交互。

## 核心角色和权限

### 顾客

顾客主要能力：

- 手机号注册。
- 使用邀请码完成注册。
- 账号密码登录。
- 浏览酒单。
- 查看酒品详情。
- 收藏喜欢的酒。
- 加入已选酒单。
- 一次性提交多款、多杯酒。
- 查看订单状态。
- 订单完成后评论。
- 在社区发帖、点赞、查看别人主页。
- 维护自己的头像、背景、昵称和个性签名。

### 调酒师 / 管理员

管理员主要能力：

- 查看全部订单。
- 接单。
- 标记制作中。
- 标记完成。
- 设置吧台状态：空闲、忙碌、未营业。
- 新增和编辑酒品。
- 上传并裁切酒品图片。
- 维护酒类分类和备注。
- 维护库存和缺料提示。
- 查看全部顾客历史订单。
- 查看和管理评论。
- 管理社区内容。
- 使用数据库 GUI 做常用数据维护。

## 主要业务流程

### 顾客点单流程

```text
注册/登录
  -> 浏览酒单
  -> 查看酒品详情
  -> 点击 “+” 加入已选酒单
  -> 已选酒单底部浮现
  -> 可继续添加多款酒或同款多杯
  -> 确认下单
  -> 等待调酒师接单
  -> 查看订单状态
  -> 完成后评价
```

### 调酒师处理订单流程

```text
登录管理员账号
  -> 进入订单页
  -> 查看待处理订单
  -> 接单
  -> 标记制作中
  -> 完成订单
  -> 顾客侧看到完成状态
```

### 缺料点单流程

```text
管理员在库存中标记某原料缺货
  -> 酒单/详情页提示缺料
  -> 顾客仍可下单
  -> 系统提示顾客需要自备缺料
  -> 缺料信息写入订单条目备注
  -> 调酒师接单时可以看到具体哪杯酒缺什么
```

### 吧台状态流程

```text
管理员在 “我的” 页面维护吧台状态
  -> 空闲：正常点单
  -> 忙碌：顾客知道出酒可能变慢
  -> 未营业：禁止下单
```

## 技术栈

| 模块   | 技术                             |
| ---- | ------------------------------ |
| 客户端  | Flutter Web / Flutter Android  |
| 状态管理 | Riverpod                       |
| 路由   | GoRouter                       |
| 网络请求 | Dio                            |
| 实时同步 | Socket.IO                      |
| 后端   | Node.js + TypeScript + Express |
| ORM  | Prisma                         |
| 数据库  | PostgreSQL                     |
| 上传处理 | Multer + Sharp                 |
| 部署   | Docker Compose + Nginx         |

## 项目目录

```text
Drunkard/
├── app/                         # Flutter 客户端
│   ├── lib/                     # 页面、组件、接口、状态管理
│   ├── assets/                  # 图片和动画资源
│   ├── web/                     # Web 入口、图标、manifest
│   └── build/                   # 构建产物，不建议提交 Git
├── backend/                     # Node.js 后端
│   ├── prisma/                  # Prisma schema 和种子数据
│   ├── src/                     # Express 路由、控制器、服务
│   └── dist/                    # 后端构建产物
├── docs/                        # 文档
├── scripts/                     # 本地启动/停止脚本
├── dist/                        # 方便分发的构建产物，例如 APK
├── docker-compose.yml           # 本地 Docker Compose
├── docker-compose.prod.example.yml
├── nginx.conf
├── .env.production.example
├── start-local.cmd
└── stop-local.cmd
```

## 本地运行最快路径

Windows 下推荐：

```bat
start-local.cmd
```

然后打开：

```text
http://127.0.0.1:8080
```

停止：

```bat
stop-local.cmd
```

如果启动失败，先看：

```text
docs/LOCAL_RUN_CN.md
```

## 服务器上线最快路径

推荐服务器目录：

```text
/opt/drunkard
```

推荐公网端口：

```text
18080
```

生产启动：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build
```

健康检查：

```bash
curl http://127.0.0.1:18080/api/health
```

详细步骤见：

```text
docs/DEPLOYMENT_CN.md
docs/SERVER_RUNBOOK_CN.md
```

## APK 构建

如果服务器通过 IP + 端口访问：

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

如果服务器已经配置域名和 HTTPS：

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api
```

APK 输出位置：

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

为了方便分发，也可以复制到：

```text
dist/drunkard-release.apk
```

## 生产环境变量说明

生产环境使用：

```text
.env.production
```

这个文件不要上传 GitHub。示例文件是：

```text
.env.production.example
```

核心变量：

| 变量                  | 用途         | 说明                               |
| ------------------- | ---------- | -------------------------------- |
| `DB_PASSWORD`       | 数据库密码      | 必须强密码                            |
| `JWT_SECRET`        | 登录令牌签名     | 必须长随机字符串                         |
| `INVITE_CODE`       | 注册邀请码      | 只告诉允许注册的人                        |
| `ADMIN_PHONE`       | 管理员手机号     | 用于管理员初始化登录                       |
| `ADMIN_PASSWORD`    | 管理员密码      | 上线前必须改                           |
| `SERVER_URL`        | 后端公开地址     | 例如 `http://YOUR_SERVER_IP:18080` |
| `FRONTEND_URL`      | 前端公开地址     | 通常和 `SERVER_URL` 一致              |
| `CORS_ORIGINS`      | 浏览器允许来源    | 生产不要乱填 `*`                       |
| `WECHAT_APP_ID`     | 微信登录 AppID | 暂时可留空                            |
| `WECHAT_APP_SECRET` | 微信登录密钥     | 暂时可留空                            |

## 安全底线

必须做到：

- `.env.production` 不进 Git。
- 数据库端口 `5432` 不暴露公网。
- 后端端口 `3000` 不直接暴露公网。
- 管理员账号密码不要写死在源码。
- `JWT_SECRET` 不能使用默认值。
- 上传的用户图片不要进 Git。
- 服务器 SSH 私钥不要进 Git。
- 真实使用建议配置 HTTPS。

## 已知取舍

### iOS Safari 帧率

iPhone Safari 上 Flutter Web 可能不如 Android APK 和桌面浏览器丝滑。这不是某一个按钮、阴影或页面导致的，而更接近 Flutter Web 在 iOS Safari 上的渲染链路限制。

已经尝试过：

- 降低部分视觉特效。
- Flutter WebAssembly 灰度构建。
- 观察移动端交互表现。

最终结论：

- WASM 没有明显提升。
- 当前保留普通 Web 稳定版。
- 如果未来非常重视 iPhone 流畅度，应考虑 iOS 原生 App、iOS WebView 壳或单独轻量 H5。

### 微信登录

微信快捷登录入口暂时隐藏。原因是正式接入需要微信开放平台/公众号/小程序相关资质和回调配置。当前先保留手机号注册登录，避免用户看到无法使用的微信入口。

## 文档索引

英文版，适合 GitHub 开源展示：

```text
README.md
docs/LOCAL_RUN.md
docs/DEPLOYMENT.md
docs/OPERATIONS.md
docs/SERVER_RUNBOOK.md
```

中文版，适合自用维护：

```text
README_CN.md
docs/LOCAL_RUN_CN.md
docs/DEPLOYMENT_CN.md
docs/OPERATIONS_CN.md
docs/SERVER_RUNBOOK_CN.md
```
