# encountering · 遇

活动现场照片墙：手机上传一张照片，大屏滚动展示。
多场活动可复用，按 `?e=slug` 隔离数据。**本仓库是唯一代码源**（single source of truth）。

muShenzhen 2026（11 月 29 日–12 月 18 日，OCT-LOFT C2）用活动代号 `mushenzhen-2026`。不要把这场的照片放进 `mufriends-2026-11-06`。

## 目录结构

```
yu/      旧入口，只跳转到正式上传页，不再做话题卡
wall/    大屏，以及观众上传页 wall/upload/（部署后是 /upload/）
sql/     Supabase 建库、迁移，以及上场前要执行的权限脚本
```

## 线上地址

| 模块 | 地址 | 部署来源 |
|------|------|----------|
| 上传页（和墙同一域名） | https://mufriends.mushenzhen.xyz/upload/?e=mushenzhen-2026 | 本仓库 `wall/upload/`，随 `wall/` 一起 `npx wrangler deploy` |
| Paper Wall 正式站（国内可访问） | https://mufriends.mushenzhen.xyz/ | 本仓库 `wall/` 本地 `npx wrangler deploy` → Cloudflare |
| Paper Wall 备用站 | https://xiaoyug.github.io/mufriends-wall/ | 本仓库 `wall/` 同步到 [xiaoyug/mufriends-wall](https://github.com/xiaoyug/mufriends-wall) → GitHub Pages |
| 云端 | Supabase 项目 `kqttuewfmvuuohvqbhel` | `sql/` 脚本建库 |

> 同步用 `git subtree split` 把子目录推到部署仓库（见 AGENTS.md「部署流程」），
> yu 和 mufriends-wall 两个仓库是**只读镜像，不要直接改**。

## 三分钟上手（开一场新活动）

1. 上场前在 Supabase 执行 [sql/mushenzhen-2026-rls.sql](sql/mushenzhen-2026-rls.sql)（只插入照片；按 M 隐藏。M 没有密码）
2. 大屏打开 `https://mufriends.mushenzhen.xyz/?e=mushenzhen-2026`
3. 右下角二维码指向 `https://mufriends.mushenzhen.xyz/upload/?e=mushenzhen-2026`
4. 观众选一张照片，可写说明；联系方式默认关闭，打开后只提交文字。勾选同意后才能上传
5. 按 `M` 可隐藏刚传的测试照片。根地址不带 `?e=` 仍是活动索引

本地看上传页：`node wall/server.js`，打开 `http://127.0.0.1:7100/upload/?e=mushenzhen-2026`。本机和 GitHub Pages 上点上传不会写入正式照片墙。

## 活动后导出照片

```bash
cd wall
python3 export-photos.py --event 活动代号    # 按活动导出
python3 export-photos.py --live              # 只导出未被删除的
```

导出 `./export/` 目录：编号照片 + `index.csv`（昵称 / 留言 / 活动 / 时间）。

## 数据约定（两端共用，不要改字段名）

- 表 `events`：`slug`（主键）/ `name` / `date` / `slogan` / `created_at`
- 表 `photos`：`id` / `nickname`（自愿填写的联系文字，可空）/ `message`（照片说明，可空）/ `photo_url` / `event`（= events.slug）/ `deleted`（软删除）/ `created_at`
- 存储桶 `photos`：公开读。手机只应新增文件。上场前跑 [sql/mushenzhen-2026-rls.sql](sql/mushenzhen-2026-rls.sql)
- 两端都不直连 supabase.co，走 Cloudflare Worker 反代 `https://mufriends.mushenzhen.xyz/proxy`（国内稳定性）

## 文档

- [AGENTS.md](AGENTS.md) — 给 AI 协作者的项目上下文（架构、部署流程、坑）
- [yu/README.md](yu/README.md) — 旧入口说明
- [wall/README-wall.md](wall/README-wall.md) — 大屏说明
- [sql/supabase-setup.sql](sql/supabase-setup.sql) — 从零建库
- [sql/supabase-events-migration.sql](sql/supabase-events-migration.sql) — 多活动化迁移
- [sql/mushenzhen-2026-rls.sql](sql/mushenzhen-2026-rls.sql) — 2026 上场前的权限脚本（需人工执行）

## 协作

- 需求 / bug → 本仓库 Issues
- 改代码 → 直接在本仓库 `yu/` 或 `wall/` 提 PR
- 设计基调：mu 深圳海报风——白底、黑描边、硬投影、拍立得贴纸卡片、等宽字体胶囊
