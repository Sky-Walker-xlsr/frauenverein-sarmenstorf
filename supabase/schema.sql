-- ============================================================================
-- Frauenverein Sarmenstorf — Supabase schema "frv-p-01"
-- Run this once in the Supabase SQL editor (Project: frv-p-01).
--
-- Covers:
--   - "frv-p-01".events          (Jahresprogramm entries)
--   - "frv-p-01".gallery_images  (Galerie)
--   - "frv-p-01".admins          (allow-list for admin write access)
--   - RLS policies for all of the above
--   - Storage bucket "frv-buk-p-01" + storage RLS policies
--   - Seed data migrated from src/data/jahresprogramm.json
--
-- After running this:
--   1. Go to Project Settings -> API -> "Exposed schemas" and add  frv-p-01
--      (PostgREST only serves schemas listed there).
--   2. Create your admin user normally via Supabase Auth (e.g. Authentication
--      -> Users -> Add user, or sign up once through the site if you add a
--      sign-up flow). Then run the INSERT at the bottom of this file with
--      that user's UUID + email to grant admin rights.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Schema
-- ----------------------------------------------------------------------------
create schema if not exists "frv-p-01";

grant usage on schema "frv-p-01" to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

-- Admin allow-list: rows here grant write access to events/gallery.
create table if not exists "frv-p-01".admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  created_at timestamptz not null default now()
);

-- Jahresprogramm entries.
create table if not exists "frv-p-01".events (
  id         uuid primary key default gen_random_uuid(),
  date_iso   date not null,
  title_date text not null,
  date_label text,
  time       text,
  meta       text,
  text_html  text,
  -- Free-form extra fields the admin can add per event (e.g. {"start_time": "18:00"})
  extra      jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists events_date_iso_idx on "frv-p-01".events (date_iso);

-- Galerie images. storage_path is the object path inside the frv-buk-p-01 bucket.
create table if not exists "frv-p-01".gallery_images (
  id           uuid primary key default gen_random_uuid(),
  storage_path text not null,
  alt          text,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now()
);

create index if not exists gallery_images_sort_idx on "frv-p-01".gallery_images (sort_order, created_at);

-- ----------------------------------------------------------------------------
-- updated_at trigger for events
-- ----------------------------------------------------------------------------
create or replace function "frv-p-01".set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists events_set_updated_at on "frv-p-01".events;
create trigger events_set_updated_at
  before update on "frv-p-01".events
  for each row execute function "frv-p-01".set_updated_at();

-- ----------------------------------------------------------------------------
-- is_admin() helper
--
-- security definer so it can read "frv-p-01".admins (which has no policies of
-- its own, i.e. is otherwise fully locked down) regardless of the caller's role.
-- ----------------------------------------------------------------------------
create or replace function "frv-p-01".is_admin()
returns boolean
language sql
security definer
set search_path = pg_catalog
stable
as $$
  select exists (
    select 1 from "frv-p-01".admins where user_id = auth.uid()
  );
$$;

grant execute on function "frv-p-01".is_admin() to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------
alter table "frv-p-01".admins         enable row level security;
alter table "frv-p-01".events         enable row level security;
alter table "frv-p-01".gallery_images enable row level security;

-- admins: no policies -> deny-all for anon/authenticated. Only readable via
-- the security-definer is_admin() function above.

-- events: anyone can read, only admins can write.
grant select on "frv-p-01".events to anon, authenticated;
grant insert, update, delete on "frv-p-01".events to authenticated;

create policy "events_public_read" on "frv-p-01".events
  for select using (true);

create policy "events_admin_insert" on "frv-p-01".events
  for insert with check ("frv-p-01".is_admin());

create policy "events_admin_update" on "frv-p-01".events
  for update using ("frv-p-01".is_admin()) with check ("frv-p-01".is_admin());

create policy "events_admin_delete" on "frv-p-01".events
  for delete using ("frv-p-01".is_admin());

-- gallery_images: anyone can read, only admins can write.
grant select on "frv-p-01".gallery_images to anon, authenticated;
grant insert, update, delete on "frv-p-01".gallery_images to authenticated;

create policy "gallery_images_public_read" on "frv-p-01".gallery_images
  for select using (true);

create policy "gallery_images_admin_insert" on "frv-p-01".gallery_images
  for insert with check ("frv-p-01".is_admin());

create policy "gallery_images_admin_update" on "frv-p-01".gallery_images
  for update using ("frv-p-01".is_admin()) with check ("frv-p-01".is_admin());

create policy "gallery_images_admin_delete" on "frv-p-01".gallery_images
  for delete using ("frv-p-01".is_admin());

-- ----------------------------------------------------------------------------
-- Storage bucket "frv-buk-p-01"
-- Public bucket: images are served directly via public URL, but listing /
-- writing the object catalog still goes through these RLS policies.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('frv-buk-p-01', 'frv-buk-p-01', true)
on conflict (id) do nothing;

create policy "frv_buk_p_01_public_read"
  on storage.objects for select
  using (bucket_id = 'frv-buk-p-01');

create policy "frv_buk_p_01_admin_insert"
  on storage.objects for insert
  with check (bucket_id = 'frv-buk-p-01' and "frv-p-01".is_admin());

create policy "frv_buk_p_01_admin_update"
  on storage.objects for update
  using (bucket_id = 'frv-buk-p-01' and "frv-p-01".is_admin());

create policy "frv_buk_p_01_admin_delete"
  on storage.objects for delete
  using (bucket_id = 'frv-buk-p-01' and "frv-p-01".is_admin());

-- ----------------------------------------------------------------------------
-- Seed data — migrated from src/data/jahresprogramm.json
-- ----------------------------------------------------------------------------
insert into "frv-p-01".events (date_iso, title_date, date_label, time, text_html) values
('2026-04-17', 'Freizeitplausch (7. bis 17. April 2026)', '7.–17. April 2026', null,
 'Sechs spannende Angebote für die Kinder während der Frühlingsferien. <br /><p><strong>Der falkner hat bestätigt: wir sind draussen!</strong></p>'),

('2026-05-07', 'Maiandacht (7. Mai 2026)', '07. Mai 2026', null,
 'Die Maiandacht findet in diesem Jahr um 19.30 Uhr in der Kapelle Oberniesenberg statt..<br /><p><strong>Treffpunkt:</strong> Parkplatz Kirche Sarmenstorf</p> <p><strong>Zu Fuss:</strong> 18:30 Uhr</p> <p><strong>Fahrgemeinschaften:</strong> 19:15 Uhr</p>'),

('2026-05-19', 'Führung Cinema8 Schöftland (19. Mai 2026)', '19. Mai 2026', '17:00',
 'Wir erhalten eine spannende Führung hinter der Leinwand. Im Anschluss decken wir uns mit Snacks ein und geniessen eine Kino-Vorstellung gem. Programm.<br />Treffpunkt: 17.00 Uhr Lindenplatz oder 17.55 Uhr Cinema8 in Schöftland.<br />Infos: <a href="/dokumente/Einladung_Cinema_8.pdf" target="_blank"><strong>Einladung</strong></a>'),

('2026-06-24', 'Überraschungsabend (24. Juni 2026)', '24. Juni 2026', null,
 'Infos: <a href="/dokumente/Einladung_Ueberraschungsabend_2026.pdf" target="_blank"><strong>Anmelde Formular</strong>'),

('2026-08-20', 'Abendandacht im Bildstöckli (20. August 2026)', '20. August 2026', null,
 'Wir feiern die Abendandacht bei schönem Wetter beim Bildstöckli, bei schlechtem Wetter in der Kirche.'),

('2026-09-12', 'Feuerwehrhauptübung (12. September 2026)', '12. September 2026', null,
 'Wir helfen an der Feuerwehrhauptübung mit.'),

('2026-11-21', 'Kinder-Weihnachtsbasteln (21. November 2026)', '21. November 2026', null,
 'Das Kinder-Weihnachtsbasteln findet nur statt, wenn sich jemand für die Organisation zur Verfügung stellt.'),

('2026-11-27', 'Halbtagesreise (27. November 2026)', '27. November 2026', null,
 'Der Frauenverein auf Reisen. Infos von der Event-Gruppe folgen.'),

('2026-12-17', 'Adventsfeier (17. Dezember 2026)', '17. Dezember 2026', null,
 'Wir feiern besinnliche Weihnachten im Pfarreitreff. Dieser Anlass findet nur statt, wenn sich jemand für die Organisation zur Verfügung stellt .'),

('2027-01-09', 'Zunftbot (9. Januar 2027)', '9. Januar 2027', null,
 'Wir helfen am Zunftbot mit.'),

('2027-01-12', 'Filmabend (12. Januar 2027)', '12. Januar 2027', null,
 '20.00 Uhr im Pfarreitreff. Für Getränke und Snacks ist gesorgt.'),

('2027-02-26', 'Frauen-Preisjassturnier (26. Februar 2027)', '26. Februar 2027', null,
 'Es wird wieder auf den Tisch geklopft.'),

('2027-03-12', 'Generalversammlung (12. März 2027)', '12. März 2027', null,
 'Ordentliche Generalversammlung des Frauenvereins mit Rückblick, Ausblick und wichtigen Informationen zum Vereinsjahr.');

-- ----------------------------------------------------------------------------
-- Grant yourself admin access
--
-- 1. Create your user in Supabase Auth (Authentication -> Users -> Add user).
-- 2. Copy that user's UUID and run:
--
-- insert into "frv-p-01".admins (user_id, email)
-- values ('00000000-0000-0000-0000-000000000000', 'you@example.com');
-- ----------------------------------------------------------------------------
