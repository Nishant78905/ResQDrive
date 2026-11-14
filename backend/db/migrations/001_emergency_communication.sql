BEGIN;
CREATE TABLE IF NOT EXISTS revoked_tokens (jti TEXT PRIMARY KEY, expires_at TIMESTAMPTZ NOT NULL);
CREATE INDEX IF NOT EXISTS revoked_tokens_expires_idx ON revoked_tokens (expires_at);
ALTER TABLE emergency_contacts ADD COLUMN IF NOT EXISTS notification_enabled BOOLEAN NOT NULL DEFAULT FALSE;
CREATE TABLE IF NOT EXISTS emergency_settings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  police_enabled BOOLEAN NOT NULL DEFAULT FALSE, police_phone TEXT,
  ambulance_enabled BOOLEAN NOT NULL DEFAULT FALSE, ambulance_phone TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS emergency_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  accident_id BIGINT REFERENCES accidents(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('AUTOMATIC','MANUAL')),
  idempotency_key TEXT NOT NULL, accident_timestamp TIMESTAMPTZ NOT NULL,
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  accident_severity NUMERIC(8,3),
  event_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (event_status IN ('PENDING','PROCESSING','COMPLETED','PARTIAL','FAILED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE (user_id, idempotency_key)
);
CREATE TABLE IF NOT EXISTS notification_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id BIGINT NOT NULL REFERENCES emergency_events(id) ON DELETE CASCADE,
  recipient_type TEXT NOT NULL CHECK (recipient_type IN ('POLICE','AMBULANCE','CONTACT')),
  recipient_phone TEXT NOT NULL, message TEXT NOT NULL, provider TEXT NOT NULL DEFAULT 'TEXTBEE',
  provider_message_id TEXT, sending_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (sending_status IN ('PENDING','QUEUED','SENDING','SENT','DELIVERED','FAILED','UNKNOWN')),
  error_message TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id, recipient_type, recipient_phone)
);
ALTER TABLE notification_logs DROP CONSTRAINT IF EXISTS notification_logs_sending_status_check;
ALTER TABLE notification_logs ADD CONSTRAINT notification_logs_sending_status_check CHECK (sending_status IN ('PENDING','QUEUED','SENDING','SENT','DELIVERED','FAILED','UNKNOWN'));
CREATE INDEX IF NOT EXISTS emergency_events_user_created_idx ON emergency_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notification_logs_event_idx ON notification_logs (event_id, created_at);
COMMIT;
