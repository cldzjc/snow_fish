-- Snow Fish C2C-Only Migration v1
-- 将混合的C2C+B2C系统简化为纯C2C二手交易平台
-- 支持在Supabase SQL Editor中直接运行
-- 时间戳：2026-04-21

BEGIN;

-- =========================================================
-- 1. 备份和清理B2C相关表
-- =========================================================

DO $$
BEGIN
  IF to_regclass('public.merchant_applications') IS NOT NULL
     AND to_regclass('public.merchant_applications_bak_20260421') IS NULL THEN
    EXECUTE 'CREATE TABLE public.merchant_applications_bak_20260421 AS TABLE public.merchant_applications';
    EXECUTE 'DROP TABLE IF EXISTS public.merchant_applications CASCADE';
  END IF;
END $$;

-- =========================================================
-- 2. 新增表：用户地址管理（支持多地址）
-- =========================================================

CREATE TABLE IF NOT EXISTS public.address_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  province TEXT,
  city TEXT,
  district TEXT,
  detail_address TEXT NOT NULL,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 确保每个用户最多一个默认地址
CREATE UNIQUE INDEX IF NOT EXISTS idx_address_records_user_default
  ON public.address_records(user_id)
  WHERE is_default = TRUE;

CREATE INDEX IF NOT EXISTS idx_address_records_user_id
  ON public.address_records(user_id);

-- 触发器：更新updated_at
CREATE OR REPLACE FUNCTION public.update_address_records_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_update_address_records_updated_at ON public.address_records;
CREATE TRIGGER trig_update_address_records_updated_at
BEFORE UPDATE ON public.address_records
FOR EACH ROW
EXECUTE FUNCTION public.update_address_records_updated_at();

-- =========================================================
-- 3. 修改entities表：清理extra_data中的B2C字段
-- =========================================================

-- 备份现有的extra_data用于数据恢复
ALTER TABLE public.entities
ADD COLUMN IF NOT EXISTS extra_data_bak_20260421 JSONB;

UPDATE public.entities
SET extra_data_bak_20260421 = extra_data
WHERE extra_data_bak_20260421 IS NULL;

-- 清理extra_data：仅保留C2C必需字段
UPDATE public.entities
SET extra_data = COALESCE(extra_data, '{}'::jsonb)
  || jsonb_strip_nulls(
      jsonb_build_object(
        'audit_status', COALESCE(extra_data->>'audit_status', 'approved'),
        'condition_level', extra_data->>'condition_level',
        'trade_mode', extra_data->>'trade_mode',
        'price', extra_data->'price',
        'location', extra_data->>'location',
        'is_hidden', COALESCE((extra_data->>'is_hidden')::BOOLEAN, FALSE)
      )
    )
WHERE entity_type = 'product';

-- =========================================================
-- 4. 修改orders表：删除biz_type，添加express_no和address_id
-- =========================================================

-- 添加新字段：快递单号、收货地址关联
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS express_no TEXT,
ADD COLUMN IF NOT EXISTS address_id UUID REFERENCES public.address_records(id) ON DELETE SET NULL;

-- 删除biz_type字段和约束
ALTER TABLE public.orders
DROP CONSTRAINT IF EXISTS orders_biz_type_check;

ALTER TABLE public.orders
DROP COLUMN IF EXISTS biz_type;

-- 创建新的status约束，仅保留C2C状态值
DO $$
BEGIN
  ALTER TABLE public.orders
    DROP CONSTRAINT IF EXISTS orders_status_check;
  
  ALTER TABLE public.orders
    ADD CONSTRAINT orders_status_check
    CHECK (status IN ('pending_payment', 'pending_ship', 'pending_receive', 'completed', 'cancelled'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_orders_address_id
  ON public.orders(address_id);

CREATE INDEX IF NOT EXISTS idx_orders_express_no
  ON public.orders(express_no);

-- =========================================================
-- 5. 修改user_profiles表：简化role字段
-- =========================================================

-- 添加role约束：仅user/admin两种
DO $$
BEGIN
  ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_role_check;
  
  ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('user', 'admin'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 将所有'merchant'和其他非法role改为'user'
UPDATE public.user_profiles
SET role = 'user'
WHERE role NOT IN ('user', 'admin');

-- =========================================================
-- 6. 清理order_status_history中的B2C相关记录
-- =========================================================

-- 如果有biz_type相关的历史记录，保留但标记为C2C
UPDATE public.order_status_history
SET change_reason = COALESCE(change_reason, '') || ' [auto-migrated-to-c2c]'
WHERE change_reason IS NULL AND order_id IN (
  SELECT id FROM public.orders WHERE status IN ('pending_payment', 'pending_ship', 'pending_receive', 'completed', 'cancelled')
);

-- =========================================================
-- 7. 验证和日志
-- =========================================================

-- 创建迁移日志表
CREATE TABLE IF NOT EXISTS public.migration_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  migration_name TEXT NOT NULL,
  executed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  status TEXT,
  notes TEXT
);

-- 记录本次迁移
INSERT INTO public.migration_logs (migration_name, status, notes)
VALUES (
  'c2c_only_migration_v1',
  'completed',
  'Successfully migrated from C2C+B2C to pure C2C system. Created address_records table, cleaned extra_data, simplified role field, and added express_no/address_id columns to orders.'
);

-- =========================================================
-- 8. 后续检查清单（手动验证）
-- =========================================================
-- SELECT COUNT(*) as total_entities FROM public.entities WHERE entity_type = 'product';
-- SELECT COUNT(*) FROM public.entities WHERE entity_type = 'product' AND (extra_data->>'audit_status') IS NULL;
-- SELECT DISTINCT role FROM public.user_profiles; -- 应该仅有'user'和'admin'
-- SELECT COUNT(*) FROM public.address_records; -- 应该为0（用户首次购买时创建）
-- SELECT COUNT(*) FROM public.orders WHERE express_no IS NOT NULL; -- 快递单号数量
-- SELECT COUNT(*) FROM public.orders WHERE status NOT IN ('pending_payment', 'pending_ship', 'pending_receive', 'completed', 'cancelled'); -- 应该为0

COMMIT;
