-- ============================================================================
-- Supabase RLS & Security Policy Verification Test Suite
-- Run against a local/staging Supabase PostgreSQL database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_policies.sql
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_user_a UUID := '11111111-1111-4111-8111-111111111111';
  v_user_b UUID := '22222222-2222-4222-8222-222222222222';
  v_count INT;
  v_tx_a UUID;
  v_pin_leak_blocked BOOLEAN := FALSE;
  v_streak_write_blocked BOOLEAN := FALSE;
  v_audit_read_blocked BOOLEAN := FALSE;
  v_cross_insert_blocked BOOLEAN := FALSE;
BEGIN
  -- 1. Provision two test users via auth.users (triggers profiles + streaks)
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES
    (v_user_a, 'usera@example.test', '{"full_name":"User A"}', 'authenticated', 'authenticated'),
    (v_user_b, 'userb@example.test', '{"full_name":"User B"}', 'authenticated', 'authenticated')
  ON CONFLICT (id) DO NOTHING;

  -- Set a dummy pin_hash as superuser to verify column-level revocation
  UPDATE public.profiles SET pin_hash = '$argon2id$v=19$m=19456,t=2,p=1$salt$hash' WHERE id = v_user_a;

  -- 2. Switch context to User A (authenticated)
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claim.sub', v_user_a::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  -- Verify User A sees ONLY their own profile
  SELECT COUNT(*) INTO v_count FROM public.profiles;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'RLS FAIL: User A saw % profiles (expected 1)', v_count;
  END IF;

  -- Verify User A CANNOT read pin_hash column
  BEGIN
    PERFORM pin_hash FROM public.profiles WHERE id = v_user_a;
  EXCEPTION WHEN insufficient_privilege THEN
    v_pin_leak_blocked := TRUE;
  END;
  IF NOT v_pin_leak_blocked THEN
    RAISE EXCEPTION 'SECURITY FAIL: authenticated role could SELECT pin_hash!';
  END IF;

  -- Verify User A can insert own transaction (and trigger updates streak + badge)
  INSERT INTO public.transactions (user_id, type, amount, category, note)
  VALUES (v_user_a, 'saving', 150000, 'main_goal', 'Setoran pertama')
  RETURNING id INTO v_tx_a;

  SELECT current_streak INTO v_count FROM public.streaks WHERE user_id = v_user_a;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'TRIGGER FAIL: Expected streak 1 after first transaction, got %', v_count;
  END IF;

  SELECT COUNT(*) INTO v_count FROM public.user_badges WHERE user_id = v_user_a AND badge_code = 'first_save';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'TRIGGER FAIL: Expected first_save badge to unlock automatically';
  END IF;

  -- Verify User A CANNOT directly tamper with streaks
  BEGIN
    UPDATE public.streaks SET current_streak = 999 WHERE user_id = v_user_a;
  EXCEPTION WHEN insufficient_privilege THEN
    v_streak_write_blocked := TRUE;
  END;
  IF NOT v_streak_write_blocked THEN
    RAISE EXCEPTION 'SECURITY FAIL: authenticated role could UPDATE streaks directly!';
  END IF;

  -- Verify User A CANNOT read audit_logs
  BEGIN
    PERFORM COUNT(*) FROM public.audit_logs;
  EXCEPTION WHEN insufficient_privilege THEN
    v_audit_read_blocked := TRUE;
  END;
  IF NOT v_audit_read_blocked THEN
    RAISE EXCEPTION 'SECURITY FAIL: authenticated role could SELECT audit_logs!';
  END IF;

  -- Verify User A CANNOT insert transaction for User B
  BEGIN
    INSERT INTO public.transactions (user_id, type, amount, category)
    VALUES (v_user_b, 'expense', 50000, 'food');
  EXCEPTION WHEN insufficient_privilege OR check_violation OR others THEN
    v_cross_insert_blocked := TRUE;
  END;
  IF NOT v_cross_insert_blocked THEN
    RAISE EXCEPTION 'RLS FAIL: User A could INSERT transaction for User B!';
  END IF;

  -- 3. Switch context to User B and verify complete isolation from User A
  PERFORM set_config('request.jwt.claim.sub', v_user_b::TEXT, true);

  SELECT COUNT(*) INTO v_count FROM public.transactions;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'RLS FAIL: User B saw % transactions belonging to User A', v_count;
  END IF;

  UPDATE public.transactions SET amount = 1 WHERE id = v_tx_a;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'RLS FAIL: User B updated User A transaction!';
  END IF;

  DELETE FROM public.transactions WHERE id = v_tx_a;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'RLS FAIL: User B deleted User A transaction!';
  END IF;

  RAISE NOTICE 'ALL RLS, COLUMN-SECURITY, AND GAMIFICATION TRIGGER TESTS PASSED.';
END;
$$;

ROLLBACK;
