-- ============================================================================
-- Migration 002: Row Level Security (RLS), Column-Level Security & Auth Sync
-- Enforces strict per-user isolation on every user-data table and ensures
-- pin_hash & lockout counters are never readable or writable by clients.
-- ============================================================================

-- 1. Enable and force RLS on every table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions FORCE ROW LEVEL SECURITY;

ALTER TABLE public.streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streaks FORCE ROW LEVEL SECURITY;

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges FORCE ROW LEVEL SECURITY;

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;

-- 2. Column-level privileges for profiles (pin_hash & lockout fields protected)
REVOKE ALL ON public.profiles FROM anon, authenticated;

GRANT SELECT (
  id,
  email,
  full_name,
  avatar_url,
  pin_set_at,
  savings_target,
  savings_target_title,
  savings_target_deadline,
  onboarding_completed,
  notifications_enabled,
  reminder_hour,
  created_at,
  updated_at
) ON public.profiles TO authenticated;

GRANT UPDATE (
  full_name,
  avatar_url,
  savings_target,
  savings_target_title,
  savings_target_deadline,
  onboarding_completed,
  notifications_enabled,
  reminder_hour,
  fcm_token
) ON public.profiles TO authenticated;

-- Transactions: full CRUD for own rows only
REVOKE ALL ON public.transactions FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transactions TO authenticated;

-- Streaks & badges: read-only for clients; mutated only by DB triggers / service_role
REVOKE ALL ON public.streaks FROM anon, authenticated;
GRANT SELECT ON public.streaks TO authenticated;

REVOKE ALL ON public.user_badges FROM anon, authenticated;
GRANT SELECT ON public.user_badges TO authenticated;

-- Audit logs: zero access for anon/authenticated (Admin/service_role only)
REVOKE ALL ON public.audit_logs FROM anon, authenticated;

-- 3. RLS Policies — profiles
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- 4. RLS Policies — transactions
DROP POLICY IF EXISTS "transactions_select_own" ON public.transactions;
CREATE POLICY "transactions_select_own"
  ON public.transactions
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "transactions_insert_own" ON public.transactions;
CREATE POLICY "transactions_insert_own"
  ON public.transactions
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "transactions_update_own" ON public.transactions;
CREATE POLICY "transactions_update_own"
  ON public.transactions
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "transactions_delete_own" ON public.transactions;
CREATE POLICY "transactions_delete_own"
  ON public.transactions
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 5. RLS Policies — streaks
DROP POLICY IF EXISTS "streaks_select_own" ON public.streaks;
CREATE POLICY "streaks_select_own"
  ON public.streaks
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 6. RLS Policies — user_badges
DROP POLICY IF EXISTS "user_badges_select_own" ON public.user_badges;
CREATE POLICY "user_badges_select_own"
  ON public.user_badges
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 7. Automatic profile + streak provisioning on auth.users sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(
      NEW.raw_user_meta_data ->> 'full_name',
      NEW.raw_user_meta_data ->> 'name',
      split_part(COALESCE(NEW.email, 'Pengguna'), '@', 1)
    ),
    NEW.raw_user_meta_data ->> 'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.streaks (user_id, current_streak, longest_streak, total_active_days)
  VALUES (NEW.id, 0, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
