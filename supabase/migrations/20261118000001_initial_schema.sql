-- ============================================================================
-- Migration 001: Initial Schema for Tabungan Pribadi
-- Based on PRD v1.0 Section 17 with minimal, documented extensions for
-- transaction type ('saving' | 'expense'), savings target, gamification badges,
-- idempotent offline sync, and security audit logging.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. profiles
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  pin_hash TEXT,
  pin_set_at TIMESTAMPTZ,
  pin_failed_attempts SMALLINT NOT NULL DEFAULT 0 CHECK (pin_failed_attempts >= 0),
  pin_locked_until TIMESTAMPTZ,
  savings_target NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (savings_target >= 0),
  savings_target_title TEXT NOT NULL DEFAULT 'Target Tabungan Utama'
    CHECK (char_length(trim(savings_target_title)) BETWEEN 1 AND 80),
  savings_target_deadline DATE,
  onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  reminder_hour SMALLINT NOT NULL DEFAULT 20 CHECK (reminder_hour BETWEEN 0 AND 23),
  fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS
  'User profile, savings target configuration, and protected Argon2id PIN metadata.';

-- ----------------------------------------------------------------------------
-- 2. transactions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  client_id UUID,
  type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('saving', 'expense')),
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0 AND amount <= 999999999999.99),
  category TEXT NOT NULL CHECK (char_length(trim(category)) BETWEEN 1 AND 40),
  note TEXT CHECK (note IS NULL OR char_length(note) <= 140),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.transactions IS
  'User savings deposits (type=saving) and expenses (type=expense) with idempotent client_id support.';

-- ----------------------------------------------------------------------------
-- 3. streaks
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.streaks (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_streak INT NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
  longest_streak INT NOT NULL DEFAULT 0 CHECK (longest_streak >= 0),
  total_active_days INT NOT NULL DEFAULT 0 CHECK (total_active_days >= 0),
  last_active DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.streaks IS
  'Server-maintained daily activity streaks derived from transaction activity.';

-- ----------------------------------------------------------------------------
-- 4. user_badges
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_code TEXT NOT NULL CHECK (
    badge_code IN (
      'first_save',
      'consistent_10',
      'streak_3',
      'streak_7',
      'streak_30',
      'saver_1m',
      'target_50',
      'target_100'
    )
  ),
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_badges_user_code UNIQUE (user_id, badge_code)
);

COMMENT ON TABLE public.user_badges IS
  'Achievement badges unlocked automatically by database triggers from real financial activity.';

-- ----------------------------------------------------------------------------
-- 5. audit_logs (Admin / security audit trail — no client access)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL CHECK (char_length(trim(action)) BETWEEN 1 AND 64),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. Performance Indexes (PRD Section 23)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_transactions_user_occurred
  ON public.transactions (user_id, occurred_at DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_user_type_occurred
  ON public.transactions (user_id, type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_user_created_at
  ON public.transactions (user_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_user_client_id
  ON public.transactions (user_id, client_id)
  WHERE client_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_badges_user_unlocked
  ON public.user_badges (user_id, unlocked_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_reminder_lookup
  ON public.profiles (notifications_enabled, reminder_hour)
  WHERE fcm_token IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 7. Updated-at timestamp trigger
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_transactions_updated_at ON public.transactions;
CREATE TRIGGER trg_transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_streaks_updated_at ON public.streaks;
CREATE TRIGGER trg_streaks_updated_at
  BEFORE UPDATE ON public.streaks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
