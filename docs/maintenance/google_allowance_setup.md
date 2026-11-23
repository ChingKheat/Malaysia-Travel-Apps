# Verify Google allowance before enabling retrieval

The `google-places` Edge Function reserves usage in `google_api_budgets` for
search and basic details. These operations require a verified budget
for the current billing month. The Admin Database Hub shows the verified
remaining search requests.

Full place details, photos, directions and travel-time matrices use Google
Cloud quotas and billing directly. Track these requests in Google Cloud because
the Edge Function skips the Supabase allowance check and counter for them.

## Before verification

1. Replace the previously exposed Google backend key and restrict the new key to
   the required server APIs. Update the Edge Function secret, never Dart source.
   Removing a key from the working tree does not remove it from Git history or
   revoke it. Keep dedicated restricted mobile/web map keys.
2. In Google Cloud Billing/Maps usage, verify each SKU across **all projects on
   the billing account**. Allow for delayed usage reporting and outstanding calls.
   Do not infer monthly usage from the latest admin sync history.
3. Route app requests through the server proxy. For budgeted SKUs, account for
   usage by other apps, keys or projects in the baseline.

## Default limits (units per US Pacific calendar month)

| SKU in database | Default app limit | Published monthly free allowance |
|---|---:|---:|
| text_search_pro | 4,000 | 5,000 requests |
| details_pro | 4,000 | 5,000 requests |

The database accepts nonnegative limits for the operations in the table.
Published prices must be rechecked if Google changes its SKUs or free allowances.

Use a trusted SQL session to configure **each verified SKU separately**. Replace
the placeholders below with the measured usage and a review expiry (at most the
end of the current Pacific billing month). This is a template, not runnable SQL:

```sql
UPDATE public.google_api_budgets
SET baseline_usage = <conservative_total_usage_already_consumed>,
    verified_at = now(),
    valid_until = '<verified_review_expiry_with_timezone>'::timestamptz,
    enabled = true
WHERE sku = '<verified_sku>'
  AND billing_month = date_trunc('month', now() AT TIME ZONE 'America/Los_Angeles')::date;
```

Never reset `used_units`. A conservative re-verification may count some usage
twice; this blocks early rather than allowing extra spending. For a new month,
insert that month's row with its limit and leave it disabled until verification.
No automated monthly rollover enables retrieval. Short review expiries are
appropriate if external usage could change.

The admin button requires at least 48 verified search units before starting its
bounded state sync. Every actual search page reserves one unit. Basic displayed
details reserve `details_pro`. Failed or timed-out budgeted
requests are not refunded because Google may have received them.

Only `service_role` can reserve units; the mobile public key cannot modify the
budget or invoke the reservation RPC. The Edge Function verifies the user's
Auth session and admin role before searches. Missing secrets/database failures
block Google calls. Built-in `SUPABASE_SERVICE_ROLE_KEY` stays server-side.

To pause a SKU, set `enabled=false`. Alert-only Cloud budgets do not stop calls;
this database gate enforces the application's request limits. Google Maps SDK
loads, Vision, Translation, Weather and Gemini have separate billing and are
not covered by this Places/Routes counter.

## Recovery and verification

`docs/supabase_schema.sql` is the complete recovery DDL, including reference
sanitization, usage budgets and recognition tables. Existing projects use
`docs/google_places_usage_update.sql`; the snapshot guard is included there.
Re-running either does not reset counters or verify allowance.

Run `tool/checks/google_usage_database_test.sql` after migration. It verifies
limits, blocked states, privileges and sanitization inside a rolled-back
transaction. Run the Node proxy tests and `flutter test` too. No full import is
needed for these checks.

References:
- https://developers.google.com/maps/billing-and-pricing/pricing
- https://developers.google.com/maps/documentation/places/web-service/policies
