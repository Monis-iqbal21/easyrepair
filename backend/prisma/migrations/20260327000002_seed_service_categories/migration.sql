-- Seed default service categories so the bookings API can resolve category names.
-- Uses ON CONFLICT DO NOTHING so re-running is safe.

INSERT INTO "service_categories" ("id", "name", "description", "isActive", "createdAt", "updatedAt")
VALUES
  (gen_random_uuid(), 'AC Technician',  'Air conditioning installation, repair & maintenance', true, now(), now()),
  (gen_random_uuid(), 'Electrician',    'Electrical wiring, fuse boards, fixtures & repairs',  true, now(), now()),
  (gen_random_uuid(), 'Plumber',        'Pipe fitting, leaks, drains & plumbing fixtures',      true, now(), now()),
  (gen_random_uuid(), 'Handyman',       'General home repairs, assembly & odd jobs',            true, now(), now()),
  (gen_random_uuid(), 'Painter',        'Interior and exterior painting services',              true, now(), now()),
  (gen_random_uuid(), 'Carpenter',      'Furniture, woodwork & custom carpentry',               true, now(), now()),
  (gen_random_uuid(), 'Cleaner',        'Deep cleaning, regular cleaning & post-move clean',    true, now(), now())
ON CONFLICT (name) DO NOTHING;
