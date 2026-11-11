# Google 资料抓取并保存

需要更新所有已存景点的营业时间、评分等最新资料，请使用新入口 **Update saved places**，详见 [全州更新步骤](update_existing_places.zh-CN.md)。下文的按页操作仅用于 Basic 资料。

现已按要求修改为：管理员调用 Google API，再保存真实字段到 Supabase 原始 places 表。此前“仅保存 ID、强制把名称与坐标清空”的限制已移除。

## 管理员操作

1. 打开 Database Hub，选择州属。
2. 点击 Fetch and save this page，每页最多 20 条。
3. 等待出现 saved 数量，再在 Supabase 查询原始 places 表。
4. 切下一页继续。请求失败会显示原因；已有分类、室内／室外不被覆盖。

Basic Details 保存名称、坐标、归属说明及 google_fetched_at。评分和营业时间不是 Basic 请求字段，未请求到时保留已有值；NULL 表示没有获取，不能填假数据。照片 URL 和 API Key 不保存。游客接口和本地行程快照暂时仍按原实时详情流程工作。

```sql
SELECT place_id, name, state, latitude, longitude, google_fetched_at
FROM public.places
WHERE google_fetched_at IS NOT NULL
ORDER BY google_fetched_at DESC;

SELECT count(*) AS total,
       count(*) FILTER (WHERE name = 'Saved Google place') AS pending
FROM public.places;
```

本次通过登录中的管理员会话完成首批验证：第一次写入 1 条后发现回读坐标的浮点精度差异，修正比较方式后再写入 20 条，全部回读成功。云端核对：总数 1,955，已有真实名称与坐标 21，待补齐 1,934，未分类仍为 972。结果见 google_save_result.json（记录第二批 20 条）；旧占位记录要实际调用 Google 后才能变成真实资料。

本次完整 Flutter 回归为 131 项通过，1 项原有种子账号登录失败。管理员保存相关测试通过；已成功热重载应用。数据库恢复重复执行与权限测试通过。

恢复脚本同步更新了触发器和新增字段。可运行 node tool/database/validate_places_directory.mjs 验证恢复重复执行及读取权限。Google 的内容存储和使用仍受适用服务条款约束，抓取时间不代表获得无限期存储授权。
