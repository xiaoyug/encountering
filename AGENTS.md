# AGENTS.md · encountering 项目上下文（给 AI 协作者）

> 读这份文件就能获得整个系统的全貌。改代码前先看「部署流程」和「坑」两节。
> **本仓库是唯一代码源**，所有改动都在 `yu/` 或 `wall/` 里进行。

## 一句话

活动工具：手机在同一域名上传一张照片 → 推 Supabase → 大屏约 5 秒内弹出并汇入滚动照片墙。多活动复用，`?e=slug` 隔离数据。muShenzhen 2026 用 `mushenzhen-2026`，不要写进 `mufriends-2026-11-06`。

## 架构

```
手机浏览器                Cloudflare                  Supabase 免费项目
┌─────────────┐    ┌──────────────────────┐    ┌────────────────────┐
│ wall/upload/ │──▶ │ mufriends.mushenzhen │──▶ │ Postgres:          │
│  /upload/    │    │ .xyz/proxy/* 反代     │    │  · events 表       │
└─────────────┘    │  (国内直连 supabase   │    │  · photos 表       │
┌─────────────┐    │   .co 不稳，故反代)   │    │ Storage:           │
│ wall/ 大屏   │──▶ │                      │    │  · photos 桶(公开) │
│ (滚动照片墙) │    │ 静态托管大屏和上传页  │    └────────────────────┘
└─────────────┘    └──────────────────────┘
```

- 两端都是**纯静态、无构建、无框架**。上传页是 cache-first PWA（`wall/upload/sw.js`）
- 轮询而非实时订阅：大屏每 5 秒拉一次新照片（简单可靠，量小）
- 匿名密钥公开在客户端。上场前执行 `sql/mushenzhen-2026-rls.sql`：手机只能插入照片；按 M 只能把 `deleted` 改成 true。M 没有密码，知道大屏地址的人都能隐藏照片

## 仓库结构

```
yu/      旧入口，只说明上传页已迁走。不要再把话题卡接到大屏
wall/    大屏，以及 wall/upload/（index.html / app.js / config.js / sw.js / mushenzhen-full-green.svg）
         其余：config.js / server.js / worker.js / wrangler.toml / vendor/ / assets/
sql/     建库、迁移，以及 mushenzhen-2026-rls.sql（上场前人工执行）
```

部署镜像（**只读，不直接改**）：

| 镜像 | 内容 | 触发什么 |
|------|------|----------|
| xiaoyug/yu | `yu/` 的子树 | push → GitHub Pages 上线 xiaoyug.github.io/yu |
| xiaoyug/mufriends-wall | `wall/` 的子树 | push → 备用站；正式站另需 wrangler deploy |

## 部署流程（关键）

### 改上传页（wall/upload/）

1. 改被缓存的文件后**必须 bump `wall/upload/sw.js` 里的 CACHE 版本号**，并同步页脚 `upload vN`（当前 upload v1）
2. 上传页随大屏一起部署：`cd wall && npx wrangler deploy`。不要把观众指到 `xiaoyug.github.io/yu`
3. 用户端是 cache-first：新版往往要**连开两次**才生效

### 改大屏（wall/）

1. 本地预览：`node wall/server.js`（默认 7100 端口）
2. 备用站：`git subtree split --prefix=wall main` → force push 到 xiaoyug/mufriends-wall
3. **正式站必须另跑**：`cd wall && npx wrangler deploy`（wrangler.toml 已绑定 mufriends.mushenzhen.xyz 自定义域）

### Supabase

- anon key：`sb_publishable_TeAH2DCcPXl2e-MVtwyPOQ_kIEQ79YB`（公开可写，见架构节）
- 两端配置走 `https://mufriends.mushenzhen.xyz/proxy` 反代（通用透传，新增表自动可用）
- **免费版闲置约 7 天自动暂停**：暂停后 DNS NXDOMAIN、反代 530。数据不丢，Dashboard 点 Resume project 恢复
- 表结构变更：SQL Editor 执行 `sql/` 下脚本

## 多活动机制

- 大屏 URL `?e=slug` 进活动页；slug 不存在时自动在 events 表建档（name=slug、date=当天本地日期）
- 不带参数的根地址是活动索引页
- 大屏右下角二维码指向 `uploadUrl`，并带上 `?e=slug`。本场是 `https://mufriends.mushenzhen.xyz/upload/?e=mushenzhen-2026`
- 上传页只传客人选的照片。说明进 `message`，联系方式默认关；打开后只保存客人输入的文字，进 `nickname`。不上传二维码，不合成卡片
- 活动名称和日期可改，但照片仍留在 URL 里的那场。无 `?e=` 时用 `mushenzhen-2026`
- 同意勾选是必填。文案尚未经法务确认
- 大屏按 M 进管理模式：软删除 + 编辑活动信息。M 没有密码

## 坑（都踩过）

1. **wrangler deploy 和 git push 是两回事**——只 push 不 deploy，正式站不会变
2. **改 yu 不 bump sw.js 版本号 = 用户端看不到改动**；排查先说「连开两次」
3. **github.com 直连在国内夜间会大面积超时**，但 api.github.com 正常——可用 GitHub API（push_files）应急推送文本文件；含图片等二进制时只能等网络恢复走 git
4. **localhost:7100 可能被本机其他 dev server 占用**（IPv6 ::1 优先），验证时用 127.0.0.1:7100
5. Cloudflare 对脚本 UA 会 403——curl 验证带浏览器 UA
6. wrangler.toml 的 compatibility_date 不能填 UTC「未来」日期
7. 自动建档日期**不要用 toISOString()**（UTC 会差一天），用本地日期拼接
8. Supabase 暂停恢复后，PostgREST schema cache 可能需几秒刷新，PGRST205 稍等重试

## 现场运维速查

| 情况 | 处理 |
|------|------|
| 大屏照片没了 / fail to load | 八成是 Supabase 暂停 → Dashboard Resume；其次看左下角状态灯（红=连接异常） |
| 上传报 fetch error | 查手机网络能否打开 mufriends.mushenzhen.xyz；备用方案扫 github.io 的二维码 |
| 要删乱传的照片 | 大屏按 M → 点照片 ✕ |
| 要删测试活动 | Supabase Dashboard → Table Editor → events 表删行（大屏暂无删活动 UI） |
| 导出照片 | `cd wall && python3 export-photos.py --event <slug>` |

## 联系人

Owner: Sunny（xiaoyug）· mu 深圳社区
