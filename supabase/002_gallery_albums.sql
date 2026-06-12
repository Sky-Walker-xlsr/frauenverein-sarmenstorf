-- ============================================================================
-- Frauenverein Sarmenstorf — Galerie "Anlässe" (albums)
-- Run this once in the Supabase SQL editor, after schema.sql.
--
-- Adds:
--   - "frv-p-01".gallery_albums          (Anlass containers: title, description)
--   - "frv-p-01".gallery_images.album_id (nullable FK; null = unassigned)
--   - RLS policies for gallery_albums (same public-read / admin-write pattern)
--
-- After running this, PostgREST is asked to reload its schema cache via
-- NOTIFY (no container restart needed).
-- ============================================================================

create table if not exists "frv-p-01".gallery_albums (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

drop trigger if exists gallery_albums_set_updated_at on "frv-p-01".gallery_albums;
create trigger gallery_albums_set_updated_at
  before update on "frv-p-01".gallery_albums
  for each row execute function "frv-p-01".set_updated_at();

alter table "frv-p-01".gallery_images
  add column if not exists album_id uuid references "frv-p-01".gallery_albums (id) on delete set null;

create index if not exists gallery_images_album_idx on "frv-p-01".gallery_images (album_id);

alter table "frv-p-01".gallery_albums enable row level security;

grant select on "frv-p-01".gallery_albums to anon, authenticated;
grant insert, update, delete on "frv-p-01".gallery_albums to authenticated;

create policy "gallery_albums_public_read" on "frv-p-01".gallery_albums
  for select using (true);

create policy "gallery_albums_admin_insert" on "frv-p-01".gallery_albums
  for insert with check ("frv-p-01".is_admin());

create policy "gallery_albums_admin_update" on "frv-p-01".gallery_albums
  for update using ("frv-p-01".is_admin()) with check ("frv-p-01".is_admin());

create policy "gallery_albums_admin_delete" on "frv-p-01".gallery_albums
  for delete using ("frv-p-01".is_admin());

-- Ask PostgREST to pick up the new table/column without a container restart.
notify pgrst, 'reload schema';
