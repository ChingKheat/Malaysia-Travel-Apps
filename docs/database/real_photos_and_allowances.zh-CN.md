# 真实照片与可配置额度（2026-11-12）

已移除景点名称／分类到 Unsplash 的硬编码映射。无明确照片的本地景点显示暂无照片，不再套用城市、工地、餐厅等示意图。尚未关联 Google Place ID 的本地景点不会自动猜测对应 Google 地点。

Google 搜索与 Basic Details 现在请求 photos 引用；管理员新增或刷新景点时保存到 places.google_photos，最多保留 8 张，含作者信息。引用只接受该景点 ID 下的资源路径。详情页继续按需加载真实 Google 图片，并处理失效引用；不会因为打开详情页自动把图片上传到 Storage。已显式关联到景点的图片 URL 仍可显示，但已禁用自动拼接 Storage 地址和图库示意图。

完整详情移除了 editorialSummary：该字段会触发更高类别，而现有额度记在 details_enterprise 下。营业时间和评分继续更新；缺失简介不代表图片或更新出错。

## 额度

11 月的 details_enterprise 与 photos 上限设为各 5,000。变更前已用次数分别为 800 和 67；变更不清零它们，不改变 baseline_usage、verified_at、valid_until 或 enabled。云端 google-places 已部署 v12；认证、管理员搜索权限、请求限速与原有额度预留逻辑保留。

request_limit 现在可配置为非负整数，不再被表约束硬限制为 800。修改仍受管理员 RLS 限制。新环境恢复仍默认禁用额度，不自动启用或重置已有月份。

```sql
SELECT sku, billing_month, request_limit, used_units, baseline_usage,
       request_limit - used_units - baseline_usage AS remaining,
       enabled, valid_until
FROM public.google_api_budgets
WHERE sku IN ('details_enterprise', 'photos')
ORDER BY billing_month DESC, sku;
```

## 手动验证

1. 重新启动 Flutter，打开鬼仔巷本地卡片：不应再出现工地图；没有匹配照片时应显示暂无照片。
2. 打开有 Google Place ID 的景点：详情返回照片后，通过代理加载对应照片；图片失败显示错误／重试，不替换为图库图片。
3. 管理员 Discover new places 后，检查新记录 google_photos 的资源名是否以 places/该记录ID/photos/ 开头。
4. Update saved places 点击 Resume，确认原进度继续；成功写入后检查营业时间和评分。

## 已执行检查

代理自动测试 14 项通过；Flutter 最终回归 183 项通过，1 项原有种子账号登录断言失败。隔离数据库重复恢复、可配置上限和用量保留检查通过。当前没有运行中的应用登记到 DTD，因此没有完成这轮热重载或真实登录会话的图片端到端验证。
