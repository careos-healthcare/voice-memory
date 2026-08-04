ALTER TABLE billing_entitlements
  ADD COLUMN IF NOT EXISTS billing_period_start timestamptz;

ALTER TABLE billing_entitlements
  ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz;
