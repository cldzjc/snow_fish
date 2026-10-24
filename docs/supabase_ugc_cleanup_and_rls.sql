-- Snow Fish UGC cleanup and RLS hardening
-- Run this file manually in Supabase SQL Editor.
-- This is intentionally not executed by the read-only Supabase MCP.
--
-- WARNING: the DROP TABLE statements permanently remove the selected tables
-- and their data. Export a backup first if any historical data may be needed.

BEGIN;

-- ============================================================
-- 1. Permanently remove unused transaction, governance, and
--    migration-history tables.
-- ============================================================

DROP TABLE IF EXISTS public.order_status_history CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.address_records CASCADE;
DROP TABLE IF EXISTS public.admin_actions_bak_20260419 CASCADE;
DROP TABLE IF EXISTS public.merchant_applications_bak_20260419 CASCADE;
DROP TABLE IF EXISTS public.migration_logs CASCADE;

-- These functions only support the deleted transaction/address tables.
DROP FUNCTION IF EXISTS public.ensure_order_no() CASCADE;
DROP FUNCTION IF EXISTS public.log_order_status_history() CASCADE;
DROP FUNCTION IF EXISTS public.update_address_records_updated_at() CASCADE;

-- ============================================================
-- 2. Helper functions used by RLS and profile role protection.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.prevent_non_admin_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an administrator can change a profile role';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_user_profile_role ON public.user_profiles;
CREATE TRIGGER protect_user_profile_role
BEFORE UPDATE ON public.user_profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_non_admin_role_change();

-- ============================================================
-- 3. Enable RLS on the current UGC tables.
-- ============================================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interaction_counters ENABLE ROW LEVEL SECURITY;

-- Remove every policy currently attached to these tables. This also removes
-- policies created by older migrations whose names are not known here.
DO $$
DECLARE
  existing_policy record;
BEGIN
  FOR existing_policy IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'user_profiles',
        'entities',
        'media',
        'comments',
        'interactions',
        'interaction_counters'
      )
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      existing_policy.policyname,
      existing_policy.schemaname,
      existing_policy.tablename
    );
  END LOOP;
END $$;

-- Remove policies created by earlier migrations so this script is
-- repeatable and does not leave broader policies active.
DROP POLICY IF EXISTS user_profiles_select_public ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_insert_self ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_update_self ON public.user_profiles;
DROP POLICY IF EXISTS user_profiles_update_admin ON public.user_profiles;

DROP POLICY IF EXISTS entities_select_public_posts ON public.entities;
DROP POLICY IF EXISTS entities_insert_self ON public.entities;
DROP POLICY IF EXISTS entities_update_owner ON public.entities;
DROP POLICY IF EXISTS entities_update_admin ON public.entities;
DROP POLICY IF EXISTS entities_delete_owner ON public.entities;
DROP POLICY IF EXISTS entities_delete_admin ON public.entities;

DROP POLICY IF EXISTS media_select_public ON public.media;
DROP POLICY IF EXISTS media_insert_self ON public.media;
DROP POLICY IF EXISTS media_update_owner ON public.media;
DROP POLICY IF EXISTS media_delete_owner ON public.media;

DROP POLICY IF EXISTS comments_select_visible ON public.comments;
DROP POLICY IF EXISTS comments_insert_self ON public.comments;
DROP POLICY IF EXISTS comments_update_owner ON public.comments;
DROP POLICY IF EXISTS comments_delete_owner ON public.comments;

DROP POLICY IF EXISTS interactions_select_public ON public.interactions;
DROP POLICY IF EXISTS interactions_insert_self ON public.interactions;
DROP POLICY IF EXISTS interactions_delete_self ON public.interactions;

DROP POLICY IF EXISTS interaction_counters_select_public
  ON public.interaction_counters;

-- Profiles are public because avatars and nicknames are shown in the feed.
CREATE POLICY user_profiles_select_public
ON public.user_profiles
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY user_profiles_insert_self
ON public.user_profiles
FOR INSERT
TO authenticated
WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY user_profiles_update_self
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY user_profiles_update_admin
ON public.user_profiles
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Only post entities are exposed by the current application.
CREATE POLICY entities_select_public_posts
ON public.entities
FOR SELECT
TO anon, authenticated
USING (entity_type = 'post');

CREATE POLICY entities_insert_self
ON public.entities
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND entity_type = 'post'
);

CREATE POLICY entities_update_owner
ON public.entities
FOR UPDATE
TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND entity_type = 'post'
);

CREATE POLICY entities_update_admin
ON public.entities
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (entity_type = 'post');

CREATE POLICY entities_delete_owner
ON public.entities
FOR DELETE
TO authenticated
USING (user_id = (SELECT auth.uid()));

CREATE POLICY entities_delete_admin
ON public.entities
FOR DELETE
TO authenticated
USING (public.is_admin());

-- Media is readable publicly, but can only be changed by its owner.
CREATE POLICY media_select_public
ON public.media
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY media_insert_self
ON public.media
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.entities e
    WHERE e.id = entity_id
      AND e.user_id = (SELECT auth.uid())
      AND e.entity_type = 'post'
  )
);

CREATE POLICY media_update_owner
ON public.media
FOR UPDATE
TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.entities e
    WHERE e.id = entity_id
      AND e.user_id = (SELECT auth.uid())
      AND e.entity_type = 'post'
  )
);

CREATE POLICY media_delete_owner
ON public.media
FOR DELETE
TO authenticated
USING (user_id = (SELECT auth.uid()));

-- Comments are public when visible; users own their own comments.
CREATE POLICY comments_select_visible
ON public.comments
FOR SELECT
TO anon, authenticated
USING (COALESCE(is_deleted, false) = false);

CREATE POLICY comments_insert_self
ON public.comments
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.entities e
    WHERE e.id = entity_id
      AND e.entity_type = 'post'
  )
  AND (
    parent_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.comments parent
      WHERE parent.id = parent_id
        AND parent.entity_id = entity_id
        AND COALESCE(parent.is_deleted, false) = false
    )
  )
);

CREATE POLICY comments_update_owner
ON public.comments
FOR UPDATE
TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY comments_delete_owner
ON public.comments
FOR DELETE
TO authenticated
USING (user_id = (SELECT auth.uid()));

-- Interaction rows are private-write but publicly readable for counts/status.
CREATE POLICY interactions_select_public
ON public.interactions
FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY interactions_insert_self
ON public.interactions
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND (
    (
      target_type = 'entity'
      AND interaction_type IN ('like', 'dislike', 'favorite')
      AND EXISTS (
        SELECT 1
        FROM public.entities e
        WHERE e.id = entity_id
          AND e.entity_type = 'post'
      )
    )
    OR (
      target_type = 'comment'
      AND interaction_type = 'comment_like'
      AND EXISTS (
        SELECT 1
        FROM public.comments c
        WHERE c.id = entity_id
          AND COALESCE(c.is_deleted, false) = false
      )
    )
  )
);

CREATE POLICY interactions_delete_self
ON public.interactions
FOR DELETE
TO authenticated
USING (user_id = (SELECT auth.uid()));

-- Counters are maintained by database triggers; the client only reads them.
CREATE POLICY interaction_counters_select_public
ON public.interaction_counters
FOR SELECT
TO anon, authenticated
USING (true);

-- ============================================================
-- 4. Prevent duplicate likes/favorites and equivalent reactions.
-- ============================================================

WITH duplicate_rows AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, target_type, entity_id, interaction_type
      ORDER BY created_at, id
    ) AS row_number
  FROM public.interactions
)
DELETE FROM public.interactions i
USING duplicate_rows d
WHERE i.id = d.id
  AND d.row_number > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_interactions_unique_user_target
ON public.interactions(user_id, target_type, entity_id, interaction_type);

COMMIT;

-- Verification queries (run separately after the transaction):
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- SELECT to_regclass('public.orders'),
--        to_regclass('public.order_items'),
--        to_regclass('public.order_status_history'),
--        to_regclass('public.address_records'),
--        to_regclass('public.admin_actions_bak_20260419'),
--        to_regclass('public.merchant_applications_bak_20260419'),
--        to_regclass('public.migration_logs');
