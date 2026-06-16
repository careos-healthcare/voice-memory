-- Mobile FCM device registration (applied via lib/server/db.ts AUTH_SYNC_SCHEMA_STATEMENTS)

CREATE TABLE IF NOT EXISTS mobile_push_devices (
  user_id text NOT NULL,
  device_id text PRIMARY KEY,
  platform text NOT NULL,
  fcm_token text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS mobile_push_devices_user_id_idx ON mobile_push_devices (user_id);
CREATE INDEX IF NOT EXISTS mobile_push_devices_updated_at_idx ON mobile_push_devices (updated_at DESC);
