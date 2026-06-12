# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Static marketing/info website for the Frauenverein Sarmenstorf (a Swiss women's association),
built with **Astro** and deployed as a static site to `new.frauenverein-sarmenstorf.ch` (see
`CNAME`).

## Dev commands

```bash
npm run dev       # astro dev
npm run build     # astro build → dist/
npm run preview   # preview the production build
```

No test suite, linter config, or TypeScript build step beyond Astro's own `astro check`
(not configured as a script). `tsconfig.json` extends `astro/tsconfigs/strict` and references
`worker-configuration.d.ts` / `generate-types` (a `wrangler types` script exists in
`package.json`), but there is no `wrangler.toml` in the repo — these are leftovers and not
part of the current deployment flow.

Requires a `.env` (see `.env.example`) with `PUBLIC_SUPABASE_URL` / `PUBLIC_SUPABASE_ANON_KEY`
for the Supabase project — without it, `EventList`, the Galerie page, and `/admin` fail at
runtime (build still succeeds since data loading is client-side).

## Architecture

- **`src/layouts/BaseLayout.astro`** — the single shared page shell. Every page wraps its
  content in `<BaseLayout title="..." description="..." ogImage="...">`, which renders
  `<head>` (meta/OG tags, canonical URL via `Astro.site` from `astro.config.mjs`), plus the
  shared `Header` and `Footer` components and imports global `src/styles/base.css`.
- **`src/components/header.astro`** — site nav is defined in a single `navItems` array
  (with optional `children` for dropdowns) and rendered twice from that array: once for the
  desktop nav (with `<ul class="sub">` dropdowns) and once for the mobile overlay menu. The
  mobile burger/overlay open-close logic is a vanilla inline `<script>` at the bottom of this
  file. **When adding/removing a page that should appear in navigation, edit `navItems` once**
  — both menus update from the same source.
- **Per-page structure**: each `src/pages/*.astro` file imports `BaseLayout`, an optional
  page-specific stylesheet from `src/styles/<page>.css`, and wraps a `<section class="section">`
  / `<div class="container">` content block. Styling is per-page CSS files, no shared component
  library beyond `header`/`footer`/`EventList`.
- **`src/components/EventList.astro`** — events/agenda system shared across the homepage,
  `anlaesse`, and `jahresprogramm` pages. Data lives in Supabase (`"frv-p-01".events`, see
  "Supabase backend" below), not in a local JSON file.
  - The component renders an empty container server-side, then a client `<script>` fetches all
    rows from `events` (ordered by `date_iso`), builds `.event-card` elements (each with
    `data-date`), filters to only `date_iso >= today`, optionally truncates to the `limit`
    prop, and shows an "Aktuell sind keine bevorstehenden Anlässe erfasst." message if nothing
    remains.
  - `text_html` is inserted via `innerHTML` (trusted content, authored by admins in `/admin`),
    so it can contain raw HTML (links, `<strong>`, `<span style="...">` for color/uppercase).
  - Any keys in the per-event `extra` jsonb column are rendered generically as `"Key: value"`
    lines — this is how admins add ad-hoc fields (e.g. a start time) without schema changes.
  - `variant` prop (`'preview' | 'grid' | 'list'`) only changes the wrapper CSS class
    (`events-list` vs `events-grid events-grid--<variant>`) — filtering logic is identical.
- **`src/pages/galerie.astro`** — fetches `"frv-p-01".gallery_images` client-side, resolves
  each `storage_path` to a public URL via `supabase.storage.from(GALLERY_BUCKET).getPublicUrl()`,
  and renders a grid with a simple lightbox (click to enlarge, `Esc`/backdrop click to close).
- **Forms** (e.g. `freizeitplausch_form.astro`) submit to **Formspree** (`action="https://formspree.io/f/..."`)
  via a `fetch` POST with `FormData` in an inline `<script>`, with client-side validation,
  a hidden `message` field built by a `buildSummary()` function that concatenates form values
  into a readable text block, and a success `.fp-modal` shown on success instead of a redirect.
- **`public/`** — static assets referenced by absolute path (`/images/...`, `/dokumente/...pdf`,
  `/js/...`). PDFs in `public/dokumente/` are linked directly from event `text_html` entries.

## Supabase backend

This site is otherwise static, but content for Jahresprogramm and Galerie lives in a Supabase
project. All app tables/functions live in the **`"frv-p-01"`** Postgres schema (note the
hyphens — must be double-quoted in every SQL statement; `src/lib/supabase.ts` configures the
JS client with `db: { schema: 'frv-p-01' }` so `.from()`/`.rpc()` calls don't need to repeat it).

- **`supabase/schema.sql`** — full setup script (tables, RLS policies, storage bucket + storage
  policies, seed data). Run manually in the Supabase SQL editor — there is no migration runner.
  Re-running is mostly idempotent (`create table if not exists`, `on conflict do nothing`) except
  for the `create policy` statements, which fail if already present.
- **Tables**: `"frv-p-01".events` (Jahresprogramm; includes a free-form `extra jsonb` column for
  admin-defined fields), `"frv-p-01".gallery_images` (`storage_path` + `alt` + `sort_order`),
  `"frv-p-01".admins` (allow-list: `user_id` → grants admin write access, checked via the
  `"frv-p-01".is_admin()` SQL function).
- **Storage**: public bucket **`frv-buk-p-01`** for gallery images (`GALLERY_BUCKET` constant in
  `src/lib/supabase.ts`). Public read; insert/update/delete restricted to admins via
  `storage.objects` RLS policies that call `is_admin()`.
- **RLS pattern**: `events` and `gallery_images` are publicly readable; writes require
  `"frv-p-01".is_admin()` (a `security definer` function checking `auth.uid()` against the
  `admins` table — that table itself has RLS enabled with no policies, i.e. locked down except
  via this function).
- **Important**: the `"frv-p-01"` schema must be added to **Project Settings → API → Exposed
  schemas** in the Supabase dashboard, or PostgREST won't serve it.
- To grant someone admin access: create their user via Supabase Auth, then insert their
  `user_id`/`email` into `"frv-p-01".admins` (see bottom of `supabase/schema.sql`).

## Admin area (`/admin`)

Single-page, fully client-side (no SSR/middleware — this is a static site). On load it checks
`supabase.auth.getSession()` then calls the `is_admin()` RPC; shows one of: login form,
"kein Zugriff" (authenticated but not in `admins`), or the dashboard.

- **Jahresprogramm tab**: CRUD over `"frv-p-01".events` via a `<dialog>` form. The description
  field is a `contenteditable` rich-text editor (toolbar: bold, "uppercase selection" — wraps
  the selection in `<span style="text-transform:uppercase">`, font color via `execCommand`,
  clear formatting) whose `innerHTML` is saved as `text_html`. "Zusätzliche Felder" is a
  key/value list UI that serializes to the `extra` jsonb column.
- **Galerie tab**: uploads files to the `frv-buk-p-01` bucket (random UUID filenames) and
  inserts a row per file into `gallery_images`; delete removes both the storage object and the
  row.

## Content language & conventions

All user-facing content is in **Swiss German** (no i18n system — single-language site, uses
"ss" instead of "ß"). Keep new copy consistent with this.
