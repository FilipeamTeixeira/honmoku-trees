-- ============================================================================
-- Honmoku Tree Map — Supabase Schema
-- Paste this into: Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================================

-- 1. Trees (approved, canonical data)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trees (
  id          BIGSERIAL PRIMARY KEY,
  lat         DOUBLE PRECISION NOT NULL,
  lng         DOUBLE PRECISION NOT NULL,
  species_en  TEXT,
  species_jp  TEXT,
  species_lat TEXT,
  height_m    DOUBLE PRECISION,
  canopy_m2   DOUBLE PRECISION,
  age_years   INTEGER,
  notes       TEXT,
  photo_url   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Pending changes submitted by editors (awaiting admin review)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pending_changes (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tree_id              TEXT,                        -- references trees.id; TEXT to avoid FK issues during import
  action               TEXT NOT NULL CHECK (action IN ('add', 'edit', 'delete')),
  submitted_by         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  submitted_by_email   TEXT,
  submitted_at         TIMESTAMPTZ DEFAULT NOW(),
  status               TEXT NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_at          TIMESTAMPTZ,
  reviewed_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  review_note          TEXT,
  -- Proposed values (null for delete)
  lat         DOUBLE PRECISION,
  lng         DOUBLE PRECISION,
  species_en  TEXT,
  species_jp  TEXT,
  species_lat TEXT,
  height_m    DOUBLE PRECISION,
  canopy_m2   DOUBLE PRECISION,
  age_years   INTEGER,
  notes       TEXT,
  photo_url   TEXT
);

-- 3. User roles  (admin | editor)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role    TEXT NOT NULL DEFAULT 'editor' CHECK (role IN ('admin', 'editor'))
);

-- ============================================================================
-- Auto-update updated_at on trees
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trees_updated_at
  BEFORE UPDATE ON trees
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- Security helper  (SECURITY DEFINER bypasses RLS to avoid circular lookups)
-- ============================================================================
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ============================================================================
-- Row Level Security
-- ============================================================================
ALTER TABLE trees          ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles      ENABLE ROW LEVEL SECURITY;

-- Trees: public read, admin-only write
CREATE POLICY "trees_select_all"   ON trees FOR SELECT USING (true);
CREATE POLICY "trees_insert_admin" ON trees FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "trees_update_admin" ON trees FOR UPDATE USING (is_admin());
CREATE POLICY "trees_delete_admin" ON trees FOR DELETE USING (is_admin());

-- Pending changes: submitter or admin can read; authenticated users can insert
CREATE POLICY "pending_select" ON pending_changes FOR SELECT USING (
  submitted_by = auth.uid() OR is_admin()
);
CREATE POLICY "pending_insert" ON pending_changes FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL
);
CREATE POLICY "pending_update" ON pending_changes FOR UPDATE USING (is_admin());

-- User roles: each user can read only their own row
CREATE POLICY "roles_select_own" ON user_roles FOR SELECT USING (
  user_id = auth.uid()
);

-- ============================================================================
-- HOW TO MAKE YOURSELF ADMIN
-- After creating your user via Supabase Auth > Users > Add user, run:
--
--   INSERT INTO user_roles (user_id, role)
--   VALUES ('<paste-your-user-uuid-here>', 'admin');
--
-- ============================================================================

-- ============================================================================
-- HOW TO IMPORT EXISTING trees.geojson
-- Open import.html in your browser (after filling in Supabase credentials)
-- and click "Import to Supabase". It reads trees.geojson and bulk-inserts all
-- features.  Run it only once.
-- ============================================================================