BEGIN;

CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_email_not_blank CHECK (btrim(email) <> ''),
    CONSTRAINT users_name_not_blank CHECK (btrim(full_name) <> '')
);

CREATE TABLE revoked_tokens (
    jti TEXT PRIMARY KEY,
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE emergency_contacts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    relationship TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    preferred_channel TEXT NOT NULL DEFAULT 'SMS',
    priority SMALLINT NOT NULL,
    notification_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT contacts_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT contacts_channel_check CHECK (preferred_channel IN ('SMS', 'PUSH', 'EMAIL')),
    CONSTRAINT contacts_priority_check CHECK (priority > 0),
    CONSTRAINT contacts_phone_or_email CHECK (phone IS NOT NULL OR email IS NOT NULL),
    CONSTRAINT contacts_channel_address CHECK (
        (preferred_channel = 'SMS' AND phone IS NOT NULL) OR
        (preferred_channel = 'EMAIL' AND email IS NOT NULL) OR
        preferred_channel = 'PUSH'
    ),
    CONSTRAINT contacts_priority_per_user UNIQUE (user_id, priority)
);

CREATE TABLE emergency_settings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    police_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    police_phone TEXT,
    ambulance_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ambulance_phone TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vehicles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plate_number TEXT NOT NULL,
    model TEXT NOT NULL,
    color TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT vehicles_plate_not_blank CHECK (btrim(plate_number) <> ''),
    CONSTRAINT vehicles_model_not_blank CHECK (btrim(model) <> ''),
    CONSTRAINT vehicles_color_not_blank CHECK (btrim(color) <> ''),
    CONSTRAINT vehicles_plate_per_user UNIQUE (user_id, plate_number)
);

CREATE TABLE trips (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    start_latitude DOUBLE PRECISION,
    start_longitude DOUBLE PRECISION,
    end_latitude DOUBLE PRECISION,
    end_longitude DOUBLE PRECISION,
    distance_meters NUMERIC(10, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT trips_time_order CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT trips_distance_nonnegative CHECK (distance_meters IS NULL OR distance_meters >= 0),
    CONSTRAINT trips_start_coordinates CHECK (
        (start_latitude IS NULL AND start_longitude IS NULL) OR
        (start_latitude BETWEEN -90 AND 90 AND start_longitude BETWEEN -180 AND 180)
    ),
    CONSTRAINT trips_end_coordinates CHECK (
        (end_latitude IS NULL AND end_longitude IS NULL) OR
        (end_latitude BETWEEN -90 AND 90 AND end_longitude BETWEEN -180 AND 180)
    )
);

CREATE TABLE accidents (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    peak_g_force NUMERIC(6, 3) NOT NULL,
    gyro_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    detected_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'DETECTED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT accidents_latitude_check CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT accidents_longitude_check CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT accidents_peak_g_check CHECK (peak_g_force >= 0),
    CONSTRAINT accidents_gyro_object_check CHECK (jsonb_typeof(gyro_data) IN ('object', 'array')),
    CONSTRAINT accidents_status_check CHECK (status IN ('DETECTED', 'CANCELLED_BY_USER', 'SOS_SENT', 'RESOLVED'))
);

CREATE TABLE sos_alerts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    accident_id BIGINT NOT NULL REFERENCES accidents(id) ON DELETE CASCADE,
    contact_id BIGINT REFERENCES emergency_contacts(id) ON DELETE SET NULL,
    channel TEXT NOT NULL,
    sent_at TIMESTAMPTZ,
    delivery_status TEXT NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT sos_channel_check CHECK (channel IN ('SMS', 'PUSH', 'EMAIL')),
    CONSTRAINT sos_delivery_status_check CHECK (delivery_status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'CANCELLED')),
    CONSTRAINT sos_sent_time_check CHECK (sent_at IS NULL OR sent_at >= created_at)
);

CREATE TABLE emergency_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    accident_id BIGINT REFERENCES accidents(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('AUTOMATIC', 'MANUAL')),
    idempotency_key TEXT NOT NULL,
    accident_timestamp TIMESTAMPTZ NOT NULL,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    accident_severity NUMERIC(8, 3),
    event_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (event_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'PARTIAL', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, idempotency_key)
);

CREATE TABLE notification_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id BIGINT NOT NULL REFERENCES emergency_events(id) ON DELETE CASCADE,
    recipient_type TEXT NOT NULL CHECK (recipient_type IN ('POLICE', 'AMBULANCE', 'CONTACT')),
    recipient_phone TEXT NOT NULL,
    message TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'TEXTBEE',
    provider_message_id TEXT,
    sending_status TEXT NOT NULL DEFAULT 'PENDING' CHECK (sending_status IN ('PENDING', 'QUEUED', 'SENDING', 'SENT', 'DELIVERED', 'FAILED', 'UNKNOWN')),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (event_id, recipient_type, recipient_phone)
);

CREATE TABLE sensor_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trip_id BIGINT REFERENCES trips(id) ON DELETE SET NULL,
    sampled_at TIMESTAMPTZ NOT NULL,
    acceleration_x DOUBLE PRECISION NOT NULL,
    acceleration_y DOUBLE PRECISION NOT NULL,
    acceleration_z DOUBLE PRECISION NOT NULL,
    gyroscope_x DOUBLE PRECISION NOT NULL,
    gyroscope_y DOUBLE PRECISION NOT NULL,
    gyroscope_z DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dispatch_users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'DISPATCHER',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT dispatch_email_not_blank CHECK (btrim(email) <> ''),
    CONSTRAINT dispatch_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT dispatch_role_check CHECK (role IN ('DISPATCHER', 'ADMIN'))
);

CREATE TABLE audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id BIGINT NOT NULL,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT audit_action_check CHECK (action IN ('INSERT', 'UPDATE')),
    CONSTRAINT audit_row_data_check CHECK (
        (action = 'INSERT' AND old_data IS NULL AND new_data IS NOT NULL) OR
        (action = 'UPDATE' AND old_data IS NOT NULL AND new_data IS NOT NULL)
    )
);

CREATE INDEX emergency_contacts_user_priority_idx ON emergency_contacts (user_id, priority);
CREATE INDEX vehicles_user_idx ON vehicles (user_id);
CREATE INDEX trips_user_started_idx ON trips (user_id, started_at DESC);
CREATE INDEX accidents_user_detected_idx ON accidents (user_id, detected_at DESC);
CREATE INDEX accidents_status_detected_idx ON accidents (status, detected_at DESC);
CREATE INDEX accidents_detected_idx ON accidents (detected_at DESC);
CREATE INDEX sos_alerts_accident_idx ON sos_alerts (accident_id);
CREATE INDEX sos_alerts_contact_idx ON sos_alerts (contact_id);
CREATE INDEX sensor_events_user_sampled_idx ON sensor_events (user_id, sampled_at DESC);
CREATE INDEX audit_log_record_changed_idx ON audit_log (table_name, record_id, changed_at DESC);
CREATE INDEX revoked_tokens_expires_idx ON revoked_tokens (expires_at);
CREATE INDEX emergency_events_user_created_idx ON emergency_events (user_id, created_at DESC);
CREATE INDEX notification_logs_event_idx ON notification_logs (event_id, created_at);

CREATE FUNCTION audit_accident_change() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, NULL, to_jsonb(NEW));
        RETURN NEW;
    END IF;

    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data)
    VALUES (TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
END;
$$;

CREATE TRIGGER accidents_audit_after_change
AFTER INSERT OR UPDATE ON accidents
FOR EACH ROW EXECUTE FUNCTION audit_accident_change();

CREATE VIEW dispatch_active_accidents AS
SELECT
    a.id AS accident_id,
    a.detected_at,
    a.status,
    a.latitude,
    a.longitude,
    a.peak_g_force,
    u.id AS user_id,
    u.full_name AS driver_name,
    u.phone AS driver_phone,
    u.email AS driver_email,
    v.id AS vehicle_id,
    v.plate_number,
    v.model AS vehicle_model,
    v.color AS vehicle_color,
    ec.id AS contact_id,
    ec.full_name AS contact_name,
    ec.phone AS contact_phone,
    ec.email AS contact_email,
    sa.channel AS alert_channel,
    sa.delivery_status AS alert_delivery_status
FROM accidents AS a
JOIN users AS u ON u.id = a.user_id
LEFT JOIN vehicles AS v ON v.id = a.vehicle_id
LEFT JOIN sos_alerts AS sa ON sa.accident_id = a.id
LEFT JOIN emergency_contacts AS ec ON ec.id = sa.contact_id
WHERE a.status IN ('DETECTED', 'SOS_SENT');

-- CALL runs within the caller's transaction; an exception rolls back the accident and its alerts together.
CREATE PROCEDURE create_accident_with_sos(
    IN p_user_id BIGINT,
    IN p_vehicle_id BIGINT,
    IN p_latitude DOUBLE PRECISION,
    IN p_longitude DOUBLE PRECISION,
    IN p_peak_g_force NUMERIC,
    IN p_gyro_data JSONB,
    IN p_detected_at TIMESTAMPTZ,
    INOUT p_accident_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User % does not exist', p_user_id USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF p_vehicle_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM vehicles WHERE id = p_vehicle_id AND user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'Vehicle % does not belong to user %', p_vehicle_id, p_user_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    INSERT INTO accidents (user_id, vehicle_id, latitude, longitude, peak_g_force, gyro_data, detected_at)
    VALUES (p_user_id, p_vehicle_id, p_latitude, p_longitude, p_peak_g_force, p_gyro_data, p_detected_at)
    RETURNING id INTO p_accident_id;

    INSERT INTO sos_alerts (accident_id, contact_id, channel)
    SELECT p_accident_id, ec.id, ec.preferred_channel
    FROM emergency_contacts AS ec
    WHERE ec.user_id = p_user_id AND ec.notification_enabled = TRUE
    ORDER BY ec.priority;
END;
$$;

COMMIT;
