-- Remove the Enterprise request cap while preserving verification and usage.
BEGIN;

ALTER TABLE public.google_api_budgets DROP CONSTRAINT IF EXISTS google_api_budgets_check;
ALTER TABLE public.google_api_budgets ALTER COLUMN request_limit DROP NOT NULL;
ALTER TABLE public.google_api_budgets ADD CONSTRAINT google_api_budgets_check
  CHECK (CASE WHEN request_limit IS NULL THEN sku = 'details_enterprise' ELSE request_limit >= 0 END);

CREATE OR REPLACE FUNCTION public.reserve_google_api_usage(p_sku TEXT,p_units INTEGER)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF p_units IS NULL OR p_units<1 OR p_units>100 THEN RETURN FALSE; END IF;
  UPDATE public.google_api_budgets SET used_units=used_units+p_units
  WHERE sku=p_sku
    AND billing_month=date_trunc('month',now() AT TIME ZONE 'America/Los_Angeles')::date
    AND enabled AND verified_at IS NOT NULL AND verified_at<=now()
    AND verified_at >= (billing_month::timestamp AT TIME ZONE 'America/Los_Angeles')
    AND valid_until>now()
    AND valid_until <= ((billing_month+INTERVAL '1 month')::timestamp AT TIME ZONE 'America/Los_Angeles')
    AND (request_limit IS NULL OR baseline_usage::bigint+used_units::bigint+p_units<=request_limit)
    AND used_units::bigint+p_units<=2147483647;
  RETURN FOUND;
END $$;

UPDATE public.google_api_budgets
SET request_limit = NULL
WHERE sku = 'details_enterprise'
  AND billing_month = date_trunc('month', now() AT TIME ZONE 'America/Los_Angeles')::date;

COMMIT;
