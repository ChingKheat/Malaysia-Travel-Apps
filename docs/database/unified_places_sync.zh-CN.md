# 一个按钮同步景点

Admin Database Hub 的 **Sync places** 先发现新 ID，然后自动更新该州所有已保存 Google 景点的详情（包括刚新增的景点）。不删除搜索未命中的旧景点，不覆盖人工分类。

发现阶段每页保存；失败后重试搜索，已存 ID 不重复新增。发现阶段仍由 Hub 页面执行。详情阶段由独立任务逐个保存，进度按项目、管理员和州存在本机。离开详情页面不会暂停；重新点击 Sync places 会连接正在运行的任务，不重复启动。换设备或清除应用数据不能恢复本机进度。

Android 在详情任务运行时启动 `dataSync` 前台服务和通知，持有有时限的 CPU 唤醒锁，可切换应用或锁屏。按 Pause、任务完成、认证/额度阻断时释放服务。强制停止、划掉应用、设备重启或系统终止仍可能中断，重新进入可从保存位置恢复。iOS/web 未实现系统级后台执行，不能承诺锁屏继续。

后台完成也会记录成功日期，不依赖管理员返回页面。该改动包含 Kotlin 和 Manifest，必须重新构建安装 APK，热重载不能安装原生服务。

只有两个阶段完成且没有待处理问题才记录成功日期。无效地点、州属不符或资料不足会保留旧资料并显示问题；不能将其当作完整成功。

## 为什么有 NULL

- 旧 Discover 请求基础字段，没有请求评分、评价数量和营业时间，所以新导入时这些字段为空。统一同步的详情阶段会请求并更新它们。
- Google 没有提供的营业时间或评分仍为空，不编造数值。
- `is_indoor` 为空表示待审核，不由 Google 详情同步猜测覆盖。
- Google 照片引用存放在 `google_photos`，`photo_url` 为空不等于没有照片。照片按需读取，引用可能过期。

## 手动测试

1. 选择 Johor，点击 Sync places；确认发现阶段完成后自动进入 `Sync places · 2/2`。
2. 确认详情更新计数增加。返回 Hub、按 Home 切换应用或锁屏；重新进入后确认计数继续增加。通知在任务运行时显示，在完成后移除。按 Pause 后确认计数停止，再点同一个按钮从未完成的位置继续。
3. 完成后检查已有 Place ID 无重复、人工分类保留，且新景点也经过详情更新。
4. 比较 Google 有提供资料的景点，确认评分、营业时间及更新时间写入；未提供资料的字段允许为空。
5. 断网后确认显示暂停/失败，恢复网络后重试；失败不更新完整同步成功日期。

只读检查：

```sql
select state, count(*) as total,
       count(rating) as with_rating,
       count(operating_hours) as with_hours,
       count(*) filter (where google_photos <> '[]'::jsonb) as with_photo_refs,
       count(is_indoor) as classified
from public.places
group by state order by state;
```

搜索与逐个详情都使用各自 API 额度。搜索不能保证穷尽所有新地点。本次未修改数据库结构。

2026-11-12 验证：Android API 34 模拟器按 Home 后，原生服务 `isForeground=true`；3 个已保存的 Johor 地点在后台从 0 更新到 3，无失败，完成后服务释放。Flutter 页面卸载/任务重连测试通过；完整测试 194 项通过，1 项已有 Supabase 登录集成测试失败。

平台依据：[Android dataSync 前台服务](https://developer.android.com/develop/background-work/services/fgs/service-types#data-sync)、[Android 15 前台服务时限](https://developer.android.com/develop/background-work/services/fgs/timeout)。
