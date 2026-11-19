-- ============================================================================
-- Migration 004: Fix Service Role RLS Access & Backfill Existing Profiles
-- 1. Remove table-owner FORCE RLS which blocks service_role / Edge Functions.
-- 2. Explicitly grant service_role full access policy on all public tables.
-- 3. Backfill any user in auth.users created prior to trigger execution.
-- ============================================================================

-- 1. Disable FORCE RLS (normal ENABLE ROW LEVEL SECURITY remains active for anon/authenticated)
ALTER TABLE public.profiles NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transactions NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.streaks NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs NO FORCE ROW LEVEL SECURITY;

-- 2. Grant service_role full permissions and explicit bypass policies
GRANT ALL ON public.profiles TO service_role;
GRANT ALL ON public.transactions TO service_role;
GRANT ALL ON public.streaks TO service_role;
GRANT ALL ON public.user_badges TO service_role;
GRANT ALL ON public.audit_logs TO service_role;

DROP POLICY IF EXISTS "profiles_service_role" ON public.profiles;
CREATE POLICY "profiles_service_role"
  ON public.profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "transactions_service_role" ON public.transactions;
CREATE POLICY "transactions_service_role"
  ON public.transactions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "streaks_service_role" ON public.streaks;
CREATE POLICY "streaks_service_role"
  ON public.streaks
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "user_badges_service_role" ON public.user_badges;
CREATE POLICY "user_badges_service_role"
  ON public.user_badges
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "audit_logs_service_role" ON public.audit_logs;
CREATE POLICY "audit_logs_service_role"
  ON public.audit_logs
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 3. Backfill any users already registered in auth.users who lack a profile/streak row
INSERT INTO public.profiles (id, email, full_name, avatar_url)
SELECT
  id,
  COALESCE(email, ''),
  COALESCE(
    raw_user_meta_data ->> 'full_name',
    raw_user_meta_data ->> 'name',
    split_part(COALESCE(email, 'Pengguna'), '@', 1)
  ),
  raw_user_meta_data ->> 'avatar_url'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.streaks (user_id, current_streak, longest_streak, total_active_days)
SELECT
  id,
  0,
  0,
  0
FROM auth.users
ON CONFLICT (user_id) DO NOTHING;
