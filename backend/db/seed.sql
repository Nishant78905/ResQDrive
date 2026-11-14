BEGIN;

INSERT INTO users (email, password_hash, full_name, phone)
VALUES ('alex@example.test', 'seed-only-not-authenticatable', 'Alex Morgan', '+1-415-555-0100')
ON CONFLICT (email) DO NOTHING;

INSERT INTO emergency_contacts (user_id, full_name, relationship, phone, email, preferred_channel, priority)
SELECT u.id, seed.full_name, seed.relationship, seed.phone, seed.email, seed.preferred_channel, seed.priority
FROM users AS u
CROSS JOIN (VALUES
    ('Maya Chen', 'Partner', '+1-415-555-0184', 'maya@example.test', 'SMS', 1),
    ('Jordan Rivera', 'Sibling', '+1-415-555-0127', 'jordan@example.test', 'EMAIL', 2)
) AS seed(full_name, relationship, phone, email, preferred_channel, priority)
WHERE u.email = 'alex@example.test'
ON CONFLICT (user_id, priority) DO NOTHING;

INSERT INTO vehicles (user_id, plate_number, model, color)
SELECT id, '8RESQ24', '2023 Volvo XC60', 'Silver'
FROM users
WHERE email = 'alex@example.test'
ON CONFLICT (user_id, plate_number) DO NOTHING;

INSERT INTO trips (user_id, vehicle_id, started_at, ended_at, start_latitude, start_longitude, end_latitude, end_longitude, distance_meters)
SELECT u.id, v.id, now() - interval '2 hours', now() - interval '102 minutes',
       37.7694, -122.4862, 37.7894, -122.4012, 10300.00
FROM users AS u
JOIN vehicles AS v ON v.user_id = u.id AND v.plate_number = '8RESQ24'
WHERE u.email = 'alex@example.test'
  AND NOT EXISTS (SELECT 1 FROM trips AS t WHERE t.user_id = u.id AND t.started_at > now() - interval '1 day');

-- No credentials are provided by seed data. The placeholder hash cannot authenticate.
-- Deliberately do not seed trips, accidents, SOS events, or notification logs:
-- production screens must never present fabricated emergency history.

COMMIT;
