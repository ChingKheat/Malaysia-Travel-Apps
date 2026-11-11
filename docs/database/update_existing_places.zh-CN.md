# 更新已有景点的最新资料

## 使用方法

1. 管理员登录，打开 Database Hub，选择要更新的州。
2. 点击 **Update saved places in …**，进入更新页面。
3. 点击 **Update all saved places**。它读取该州全部已存 Google ID，逐一请求 full details 并更新数据库，不限于当前 20 条。
4. 保持页面打开；可点击 **Pause update**。返回上一页或关闭应用后，可在同一设备、同一管理员账号下点击 **Resume update** 继续。
5. 查看 updated / need review / remaining 计数。只有所有 ID 完成且没有问题时才显示全部更新成功。
6. 完整执行完毕后，再次点击 Update all saved places 会开始新一轮，因此可以定期更新变化后的营业时间。

**Discover new places** 是搜索并新增 ID，不更新已存景点。**Fetch and save this page** 是当前页的 Basic 名称／坐标更新；需要营业时间时使用上面的全州更新入口。

## 保存规则

- 更新名称、经纬度、营业时间、评分、评分人数、来源归属说明和 `google_fetched_at`。
- 保留应用分类、室内／室外、景点 ID 及州属；不会删除未返回的地点。
- Google 成功响应里的营业时间从 8–10 变成 9–11，会覆盖为 9–11。
- 完整响应中没有营业时间／评分时，将对应字段设为 NULL（未知），不继续冒充最新资料。
- 网络、登录、额度、数据库写入失败：停止在当前 ID，保留旧资料和已成功的结果，重试从这个 ID 继续。
- Google 404／410、州属不符或必需字段缺失：保留旧资料，列入问题列表，再继续其他 ID。完成后可重试问题记录，或开始新一轮全州更新。
- 重启应用后进度保存在本机；这不是后台定时任务，也不会跨设备共享进度。清除应用数据会丢失本机进度，数据库已保存资料仍保留。
- 完整详情使用 `details_enterprise` 现有额度。额度由代理逐次核验，不自动提高上限；配额不足不能承诺每个州都更新完。

## Supabase 检查

```sql
SELECT place_id, name, state, operating_hours,
       rating, user_ratings_total, google_fetched_at
FROM public.places
WHERE state = 'Penang'
ORDER BY google_fetched_at DESC NULLS LAST
LIMIT 30;
```

`google_fetched_at` 也用于 Basic 更新，判断是否完整更新应同时看本次全州更新进度和所需字段。不要仅靠时间认定营业时间一定存在。

## 已执行验证

- 自动测试覆盖跨 20 条分页、完整字段更新、额度中断后重建服务继续、数据库写入失败、暂停、无效 ID、州属不符和 320px 两倍文字页面。
- 专项测试确认旧营业时间覆盖为新营业时间、完整响应缺失字段清空、Basic 更新不清空旧营业时间、人工分类不被改动。
- 隔离 PostgreSQL 验证实际触发器会保留新营业时间和评分，恢复脚本可以重复执行。
- 真实 API 已验证 1 条 full 请求与 Supabase 写入／回读一致，结果见 `google_full_details_result.json`。没有自动执行全部 1,955 条完整详情请求。
- 完整 Flutter 回归：143 项通过、1 项原有 `supabase_integration_test.dart:79` 登录断言失败。
