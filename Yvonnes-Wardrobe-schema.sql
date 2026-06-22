-- =====================================================================
--  Yvonne's Wardrobe — Supabase schema
--  Run in: Supabase dashboard -> SQL Editor -> New query -> Run
--  Reflects app v10.9. Photos live in a Storage bucket; this is the data.
--  (v10.7 added a first-run owner-name prompt — stored per-device in
--   localStorage, display-only. v10.8 was UI-only: one-piece view layout
--   + delete moved into the edit sheet. v10.9 was UI-only: top item name
--   placement, Add-a-piece CTA always reachable, season vocabulary narrowed
--   to Summer/Winter (see note at the `season` column below). Schema
--   unchanged since v10.6.)
-- =====================================================================

-- 1) STORAGE BUCKET (create in the dashboard, not here):
--    Storage -> New bucket -> name: wardrobe-photos -> Public -> Save
--    Each item's image_path below points into this bucket.

-- 2) ITEMS — every piece of clothing
create table if not exists items (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  category    text not null check (category in ('top','bottom','dress')),  -- 'dress' = one piece
  length      text,                  -- optional; how much of the stage the garment fills (see note below)
  season      text[] default '{}',   -- v10.9: app only offers Summer or Winter (was Spring/Summer/Fall/
                                      -- Winter). No CHECK constraint was ever added, so this is a UI-layer
                                      -- restriction, not a schema one — existing Spring/Fall values in
                                      -- older rows are simply ignored by the app's filters going forward.
  occasion    text[] default '{}',   -- any of: Casual, Work, Going out, Formal, Active, Holiday
  image_path  text,                  -- path/URL of the photo in the wardrobe-photos bucket
  created_at  timestamptz default now()
);

-- 2a) MIGRATION for an EXISTING project that predates v10.6 (run once):
--     The app added an optional per-item `length` tag in v10.6. Add the
--     column before any live sync writes it. Safe to run repeatedly.
-- alter table items add column if not exists length text;
-- notify pgrst, 'reload schema';   -- make PostgREST pick up the new column

-- 2b) LENGTH vocabulary (NULLABLE — null means "untagged").
--     Allowed values DEPEND on category; the app enforces this client-side
--     and falls back to a sensible default fill when an item is untagged:
--       top    : cropped | regular | long          (default fill: regular)
--       bottom : mini | knee | midi | ankle | full  (default fill: ankle)
--       dress  : mini | knee | midi | maxi          (default fill: midi)
--     A single cross-category CHECK is intentionally omitted (the same word,
--     e.g. 'mini'/'knee'/'midi', is valid for more than one category), so the
--     column is left as free text validated in the app.

-- 3) DAY PLANS — one row per planned date (day type + the outfit)
create table if not exists day_plans (
  plan_date   date primary key,
  day_type    text check (day_type in ('Work','Social','Travel','Active')),
  top_id      uuid references items(id) on delete set null,
  bottom_id   uuid references items(id) on delete set null,
  dress_id    uuid references items(id) on delete set null
);

-- =====================================================================
--  OCCASION -> DAY TYPE mapping (handled in the app, kept here for reference)
--  Tightened in v10.4 so the day styler actually narrows the deck
--  (the old mapping let "Casual" leak into nearly every day type):
--    Work    -> Work
--    Social  -> Going out, Formal
--    Travel  -> Casual, Active, Holiday
--    Active  -> Active
-- =====================================================================

-- 4) SECURITY (current choice: simple single-user, RLS left OFF).
--    The anon key can read/write — fine for a personal app on one phone.
--    BEFORE sharing the app publicly, add login + row-level security.
--    Optional permissive policies if you ever turn RLS on:
--
-- alter table items     enable row level security;
-- alter table day_plans enable row level security;
-- create policy "anon all items"     on items     for all to anon using (true) with check (true);
-- create policy "anon all day_plans" on day_plans for all to anon using (true) with check (true);
