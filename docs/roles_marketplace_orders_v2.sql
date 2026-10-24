-- Snow Fish database migration v2
-- Safe to run in Supabase SQL Editor on top of the current schema.
-- Strategy:
-- 1) keep backups for dropped tables
-- 2) move product-specific columns into entities.extra_data
-- 3) make interactions polymorphic without changing the entity_id column name
-- 4) split orders into header/items/history

BEGIN;

-- =========================================================
-- 1. Backup and remove unused tables
-- =========================================================

DO $$
BEGIN
  IF to_regclass('public.admin_actions') IS NOT NULL
     AND to_regclass('public.admin_actions_bak_20260419') IS NULL THEN
    EXECUTE 'CREATE TABLE public.admin_actions_bak_20260419 AS TABLE public.admin_actions';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.merchant_applications') IS NOT NULL
     AND to_regclass('public.merchant_applications_bak_20260419') IS NULL THEN
    EXECUTE 'CREATE TABLE public.merchant_applications_bak_20260419 AS TABLE public.merchant_applications';
  END IF;
END $$;

DROP TABLE IF EXISTS public.admin_actions CASCADE;
DROP TABLE IF EXISTS public.merchant_applications CASCADE;

-- =========================================================
-- 2. Move product-only columns into entities.extra_data
--    Keep the data at the root level of extra_data.
-- =========================================================

ALTER TABLE public.entities
ADD COLUMN IF NOT EXISTS extra_data JSONB NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.entities
SET extra_data = COALESCE(extra_data, '{}'::jsonb) || jsonb_strip_nulls(
  jsonb_build_object(
    'audit_status', audit_status,
    'sale_status', sale_status,
    'stock_count', stock_count,
    'sold_count', sold_count,
    'reviewed_by', reviewed_by,
    'reviewed_at', reviewed_at,
    'review_note', review_note
  )
)
WHERE entity_type = 'product'
  AND (
    audit_status IS NOT NULL OR
    sale_status IS NOT NULL OR
    stock_count IS NOT NULL OR
    sold_count IS NOT NULL OR
    reviewed_by IS NOT NULL OR
    reviewed_at IS NOT NULL OR
    review_note IS NOT NULL
  );

ALTER TABLE public.entities
DROP CONSTRAINT IF EXISTS entities_audit_status_check;

ALTER TABLE public.entities
DROP CONSTRAINT IF EXISTS entities_sale_status_check;

ALTER TABLE public.entities
DROP CONSTRAINT IF EXISTS entities_reviewed_by_fkey;

DROP INDEX IF EXISTS public.idx_entities_audit_status;
DROP INDEX IF EXISTS public.idx_entities_sale_status;
DROP INDEX IF EXISTS public.idx_entities_stock_count;

ALTER TABLE public.entities
DROP COLUMN IF EXISTS audit_status,
DROP COLUMN IF EXISTS sale_status,
DROP COLUMN IF EXISTS stock_count,
DROP COLUMN IF EXISTS sold_count,
DROP COLUMN IF EXISTS reviewed_by,
DROP COLUMN IF EXISTS reviewed_at,
DROP COLUMN IF EXISTS review_note;

-- =========================================================
-- 3. Refactor interactions into a polymorphic event table
--    Keep entity_id column name so current app code still works.
-- =========================================================

ALTER TABLE public.interactions
DROP CONSTRAINT IF EXISTS interactions_entity_id_fkey;

ALTER TABLE public.interactions
ADD COLUMN IF NOT EXISTS target_type TEXT;

UPDATE public.interactions
SET target_type = CASE
  WHEN interaction_type = 'comment_like' THEN 'comment'
  ELSE 'entity'
END
WHERE target_type IS NULL;

ALTER TABLE public.interactions
ALTER COLUMN target_type SET DEFAULT 'entity';

ALTER TABLE public.interactions
ALTER COLUMN target_type SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'interactions_target_type_check'
  ) THEN
    ALTER TABLE public.interactions
      ADD CONSTRAINT interactions_target_type_check
      CHECK (target_type IN ('entity', 'comment'));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.ensure_interaction_target_type()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.interaction_type = 'comment_like' THEN
    NEW.target_type := 'comment';
  ELSIF NEW.target_type IS NULL THEN
    NEW.target_type := 'entity';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_ensure_interaction_target_type ON public.interactions;
CREATE TRIGGER trig_ensure_interaction_target_type
BEFORE INSERT OR UPDATE ON public.interactions
FOR EACH ROW
EXECUTE FUNCTION public.ensure_interaction_target_type();

-- Deduplicate before creating the unique index.
WITH ranked AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, target_type, entity_id, interaction_type
      ORDER BY created_at, id
    ) AS rn
  FROM public.interactions
)
DELETE FROM public.interactions i
USING ranked r
WHERE i.ctid = r.ctid
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_interactions_unique_user_target_type
  ON public.interactions(user_id, target_type, entity_id, interaction_type);

CREATE INDEX IF NOT EXISTS idx_interactions_target_type
  ON public.interactions(target_type);

CREATE INDEX IF NOT EXISTS idx_interactions_target_type_entity_id
  ON public.interactions(target_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_interactions_user_target
  ON public.interactions(user_id, target_type, entity_id);

-- Counter table for reads; keeps large like-count queries fast.
CREATE TABLE IF NOT EXISTS public.interaction_counters (
  target_type TEXT NOT NULL,
  target_id UUID NOT NULL,
  like_count INTEGER NOT NULL DEFAULT 0,
  dislike_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  PRIMARY KEY (target_type, target_id)
);

INSERT INTO public.interaction_counters (target_type, target_id, like_count, dislike_count, updated_at)
SELECT
  target_type,
  entity_id,
  COUNT(*) FILTER (
    WHERE interaction_type IN ('product_good', 'blog_good', 'like', 'comment_like')
  ),
  COUNT(*) FILTER (
    WHERE interaction_type IN ('product_bad', 'blog_bad', 'dislike')
  ),
  now()
FROM public.interactions
GROUP BY target_type, entity_id
ON CONFLICT (target_type, target_id) DO UPDATE
SET like_count = EXCLUDED.like_count,
    dislike_count = EXCLUDED.dislike_count,
    updated_at = now();

CREATE OR REPLACE FUNCTION public.interactions_counter_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.interaction_type IN ('product_good', 'blog_good', 'like', 'comment_like') THEN
    INSERT INTO public.interaction_counters (target_type, target_id, like_count, dislike_count)
    VALUES (NEW.target_type, NEW.entity_id, 1, 0)
    ON CONFLICT (target_type, target_id) DO UPDATE
    SET like_count = public.interaction_counters.like_count + 1,
        updated_at = now();
  ELSIF NEW.interaction_type IN ('product_bad', 'blog_bad', 'dislike') THEN
    INSERT INTO public.interaction_counters (target_type, target_id, like_count, dislike_count)
    VALUES (NEW.target_type, NEW.entity_id, 0, 1)
    ON CONFLICT (target_type, target_id) DO UPDATE
    SET dislike_count = public.interaction_counters.dislike_count + 1,
        updated_at = now();
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.interactions_counter_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.interaction_type IN ('product_good', 'blog_good', 'like', 'comment_like') THEN
    UPDATE public.interaction_counters
    SET like_count = GREATEST(0, like_count - 1),
        updated_at = now()
    WHERE target_type = OLD.target_type
      AND target_id = OLD.entity_id;
  ELSIF OLD.interaction_type IN ('product_bad', 'blog_bad', 'dislike') THEN
    UPDATE public.interaction_counters
    SET dislike_count = GREATEST(0, dislike_count - 1),
        updated_at = now()
    WHERE target_type = OLD.target_type
      AND target_id = OLD.entity_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_interactions_counter_insert ON public.interactions;
CREATE TRIGGER trig_interactions_counter_insert
AFTER INSERT ON public.interactions
FOR EACH ROW
EXECUTE FUNCTION public.interactions_counter_insert();

DROP TRIGGER IF EXISTS trig_interactions_counter_delete ON public.interactions;
CREATE TRIGGER trig_interactions_counter_delete
AFTER DELETE ON public.interactions
FOR EACH ROW
EXECUTE FUNCTION public.interactions_counter_delete();

-- Clean up orphaned comment/entity interactions when source rows are deleted.
CREATE OR REPLACE FUNCTION public.cleanup_interactions_for_comment()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.interactions
  WHERE target_type = 'comment'
    AND entity_id = OLD.id;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_cleanup_interactions_for_comment ON public.comments;
CREATE TRIGGER trig_cleanup_interactions_for_comment
AFTER DELETE ON public.comments
FOR EACH ROW
EXECUTE FUNCTION public.cleanup_interactions_for_comment();

CREATE OR REPLACE FUNCTION public.cleanup_interactions_for_entity()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.interactions
  WHERE target_type = 'entity'
    AND entity_id = OLD.id;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_cleanup_interactions_for_entity ON public.entities;
CREATE TRIGGER trig_cleanup_interactions_for_entity
AFTER DELETE ON public.entities
FOR EACH ROW
EXECUTE FUNCTION public.cleanup_interactions_for_entity();

-- =========================================================
-- 4. Orders: make it closer to a real commerce model
-- =========================================================

ALTER TABLE public.orders
DROP CONSTRAINT IF EXISTS orders_product_entity_id_fkey;

ALTER TABLE public.orders
ADD CONSTRAINT orders_product_entity_id_fkey
FOREIGN KEY (product_entity_id) REFERENCES public.entities(id) ON DELETE RESTRICT;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS order_no TEXT,
ADD COLUMN IF NOT EXISTS biz_type TEXT NOT NULL DEFAULT 'c2c',
ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'CNY',
ADD COLUMN IF NOT EXISTS item_count INTEGER NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_biz_type_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_biz_type_check
      CHECK (biz_type IN ('c2c', 'merchant'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_currency_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_currency_check
      CHECK (currency IN ('CNY', 'USD', 'EUR'));
  END IF;
END $$;

UPDATE public.orders
SET order_no = 'ORD-' || to_char(created_at, 'YYYYMMDDHH24MISS') || '-' || substr(md5(id::text), 1, 8)
WHERE order_no IS NULL;

CREATE OR REPLACE FUNCTION public.ensure_order_no()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_no IS NULL OR NEW.order_no = '' THEN
    NEW.order_no := 'ORD-' || to_char(COALESCE(NEW.created_at, now()), 'YYYYMMDDHH24MISS') || '-' || substr(md5(gen_random_uuid()::text), 1, 8);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_ensure_order_no ON public.orders;
CREATE TRIGGER trig_ensure_order_no
BEFORE INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.ensure_order_no();

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_order_no
  ON public.orders(order_no);

CREATE INDEX IF NOT EXISTS idx_orders_biz_type
  ON public.orders(biz_type);

CREATE INDEX IF NOT EXISTS idx_orders_status
  ON public.orders(status);

CREATE INDEX IF NOT EXISTS idx_orders_created_at
  ON public.orders(created_at DESC);

UPDATE public.orders o
SET snapshot_json = COALESCE(snapshot_json, '{}'::jsonb) || jsonb_strip_nulls(
  jsonb_build_object(
    'product_title', e.title,
    'product_content', e.content,
    'seller_name', e.extra_data->>'seller_name',
    'seller_avatar', e.extra_data->>'seller_avatar',
    'price', e.extra_data->'price',
    'location', e.extra_data->>'location',
    'quantity', o.quantity,
    'unit_price', o.unit_price,
    'total_price', o.total_price
  )
)
FROM public.entities e
WHERE e.id = o.product_entity_id;

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_entity_id UUID REFERENCES public.entities(id) ON DELETE SET NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  line_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT order_items_quantity_check CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
  ON public.order_items(order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_entity_id
  ON public.order_items(product_entity_id);

INSERT INTO public.order_items (
  order_id,
  product_entity_id,
  quantity,
  unit_price,
  line_total,
  snapshot_json,
  created_at
)
SELECT
  o.id,
  o.product_entity_id,
  o.quantity,
  o.unit_price,
  o.total_price,
  COALESCE(o.snapshot_json, '{}'::jsonb),
  o.created_at
FROM public.orders o
WHERE NOT EXISTS (
  SELECT 1 FROM public.order_items i WHERE i.order_id = o.id
);

CREATE TABLE IF NOT EXISTS public.order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  changed_by UUID REFERENCES auth.users(id),
  change_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id
  ON public.order_status_history(order_id);

CREATE INDEX IF NOT EXISTS idx_order_status_history_created_at
  ON public.order_status_history(created_at DESC);

INSERT INTO public.order_status_history (order_id, old_status, new_status, changed_by, created_at)
SELECT id, NULL, status, seller_id, created_at
FROM public.orders
WHERE NOT EXISTS (
  SELECT 1 FROM public.order_status_history h WHERE h.order_id = public.orders.id
);

CREATE OR REPLACE FUNCTION public.log_order_status_history()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.order_status_history(order_id, old_status, new_status, changed_by, created_at)
    VALUES (NEW.id, NULL, NEW.status, auth.uid(), now());
    RETURN NULL;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.order_status_history(order_id, old_status, new_status, changed_by, created_at)
    VALUES (NEW.id, OLD.status, NEW.status, auth.uid(), now());
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_log_order_status_history ON public.orders;
CREATE TRIGGER trig_log_order_status_history
AFTER INSERT OR UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.log_order_status_history();

-- Optional: keep product availability in the JSON field for existing product rows.
UPDATE public.entities
SET extra_data = COALESCE(extra_data, '{}'::jsonb)
  || jsonb_strip_nulls(
      jsonb_build_object(
        'audit_status', COALESCE(extra_data->>'audit_status', 'approved'),
        'sale_status', COALESCE(extra_data->>'sale_status', 'active'),
        'stock_count', COALESCE((extra_data->>'stock_count')::INT, 1),
        'sold_count', COALESCE((extra_data->>'sold_count')::INT, 0)
      )
    )
WHERE entity_type = 'product';

-- Fill transaction-track fields for existing product rows.
UPDATE public.entities e
SET extra_data = COALESCE(e.extra_data, '{}'::jsonb)
  || jsonb_strip_nulls(
      jsonb_build_object(
        'biz_type', CASE
          WHEN COALESCE(up.role, 'user') IN ('merchant', 'admin') THEN 'merchant'
          ELSE 'c2c'
        END,
        'listing_source', CASE
          WHEN COALESCE(up.role, 'user') IN ('merchant', 'admin') THEN 'merchant'
          ELSE 'idle'
        END,
        'audit_scope', CASE
          WHEN COALESCE(up.role, 'user') IN ('merchant', 'admin') THEN 'merchant_product'
          ELSE 'personal_idle'
        END,
        'seller_role', CASE
          WHEN COALESCE(up.role, 'user') IN ('merchant', 'admin') THEN 'merchant'
          ELSE 'user'
        END
      )
    )
FROM public.user_profiles up
WHERE e.entity_type = 'product'
  AND e.user_id = up.id
  AND (
    e.extra_data->>'biz_type' IS NULL OR
    e.extra_data->>'listing_source' IS NULL OR
    e.extra_data->>'audit_scope' IS NULL OR
    e.extra_data->>'seller_role' IS NULL
  );

COMMIT;