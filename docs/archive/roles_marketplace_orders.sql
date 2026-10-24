-- ========== Snow Fish 角色 / 商城 / 订单 预案脚本 ==========
-- 用于论文展示阶段的数据库设计说明。
-- 目标：先预留角色、商品审核、订单流转、管理员操作日志的表结构。

-- ------------------------------------------------------------
-- 1. 用户角色
-- ------------------------------------------------------------
-- 默认普通用户；管理员后续可认证商家或提升管理员。

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profiles_role_check'
  ) THEN
    ALTER TABLE public.user_profiles
      ADD CONSTRAINT user_profiles_role_check
      CHECK (role IN ('user', 'merchant', 'admin'));
  END IF;
END $$;

UPDATE public.user_profiles
SET role = COALESCE(role, 'user');

-- ------------------------------------------------------------
-- 2. 商家认证申请
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.merchant_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  review_note TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_merchant_applications_user_id
  ON public.merchant_applications(user_id);

CREATE INDEX IF NOT EXISTS idx_merchant_applications_status
  ON public.merchant_applications(status);

-- ------------------------------------------------------------
-- 3. 商品审核与库存状态
-- ------------------------------------------------------------
-- 说明：当前项目商品主表以 entities 为准，这里直接补字段。

ALTER TABLE public.entities
ADD COLUMN IF NOT EXISTS audit_status TEXT NOT NULL DEFAULT 'pending_review',
ADD COLUMN IF NOT EXISTS sale_status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS stock_count INTEGER NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS sold_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS review_note TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'entities_audit_status_check'
  ) THEN
    ALTER TABLE public.entities
      ADD CONSTRAINT entities_audit_status_check
      CHECK (audit_status IN ('pending_review', 'approved', 'rejected'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'entities_sale_status_check'
  ) THEN
    ALTER TABLE public.entities
      ADD CONSTRAINT entities_sale_status_check
      CHECK (
        sale_status IN (
          'active',
          'pending_payment',
          'paid',
          'waiting_shipment',
          'shipped',
          'waiting_receipt',
          'sold_out',
          'hidden',
          'rejected'
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_entities_audit_status
  ON public.entities(audit_status);

CREATE INDEX IF NOT EXISTS idx_entities_sale_status
  ON public.entities(sale_status);

CREATE INDEX IF NOT EXISTS idx_entities_stock_count
  ON public.entities(stock_count);

-- ------------------------------------------------------------
-- 4. 订单表
-- ------------------------------------------------------------
-- 一个订单对应一个商品，适合当前演示流程。

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_entity_id UUID NOT NULL REFERENCES public.entities(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending_payment'
    CHECK (
      status IN (
        'pending_payment',
        'paid',
        'waiting_shipment',
        'shipped',
        'waiting_receipt',
        'completed',
        'cancelled'
      )
    ),
  buyer_note TEXT,
  seller_note TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  paid_at TIMESTAMP WITH TIME ZONE,
  shipped_at TIMESTAMP WITH TIME ZONE,
  received_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_orders_buyer_id
  ON public.orders(buyer_id);

CREATE INDEX IF NOT EXISTS idx_orders_seller_id
  ON public.orders(seller_id);

CREATE INDEX IF NOT EXISTS idx_orders_product_entity_id
  ON public.orders(product_entity_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
  ON public.orders(status);

CREATE INDEX IF NOT EXISTS idx_orders_created_at
  ON public.orders(created_at DESC);

-- ------------------------------------------------------------
-- 5. 管理员操作日志
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id UUID,
  action_reason TEXT,
  action_payload JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id
  ON public.admin_actions(admin_id);

CREATE INDEX IF NOT EXISTS idx_admin_actions_target
  ON public.admin_actions(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at
  ON public.admin_actions(created_at DESC);

-- ------------------------------------------------------------
-- 6. 订单状态更新提示
-- ------------------------------------------------------------
-- 这里先不强制写复杂触发器，避免与现有数据流冲突。
-- 后续可在 Flutter 服务层控制状态流转：
-- pending_payment -> paid -> waiting_shipment -> shipped -> waiting_receipt -> completed

-- ------------------------------------------------------------
-- 7. 预留说明
-- ------------------------------------------------------------
-- 1) 普通用户：浏览、购买、收货、评论。
-- 2) 商家：发布商品、管理库存、发货、查看订单。
-- 3) 管理员：认证商家、审核商品、删除内容、管理评论。