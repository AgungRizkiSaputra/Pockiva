-- ============================================================================
-- Migration 003: Server-Authoritative Gamification Triggers & Summary RPCs
-- ============================================================================

-- 1. Automatic streak & badge evaluation whenever a transaction is inserted
CREATE OR REPLACE FUNCTION public.handle_transaction_gamification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx_date DATE;
  v_streak RECORD;
  v_new_current INT;
  v_new_longest INT;
  v_new_total_days INT;
  v_total_savings NUMERIC(14, 2);
  v_total_tx_count BIGINT;
  v_target NUMERIC(14, 2);
BEGIN
  -- Evaluate activity date in WIB (Asia/Jakarta) for consistent daily streaks
  v_tx_date := (NEW.occurred_at AT TIME ZONE 'Asia/Jakarta')::DATE;

  INSERT INTO public.streaks (user_id, current_streak, longest_streak, total_active_days)
  VALUES (NEW.user_id, 0, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT current_streak, longest_streak, total_active_days, last_active
    INTO v_streak
    FROM public.streaks
    WHERE user_id = NEW.user_id
    FOR UPDATE;

  IF v_streak.last_active IS NULL THEN
    v_new_current := 1;
    v_new_longest := 1;
    v_new_total_days := 1;
    UPDATE public.streaks
      SET current_streak = v_new_current,
          longest_streak = v_new_longest,
          total_active_days = v_new_total_days,
          last_active = v_tx_date
      WHERE user_id = NEW.user_id;
  ELSIF v_tx_date = v_streak.last_active THEN
    v_new_current := v_streak.current_streak;
    v_new_longest := v_streak.longest_streak;
  ELSIF v_tx_date = v_streak.last_active + 1 THEN
    v_new_current := v_streak.current_streak + 1;
    v_new_longest := GREATEST(v_streak.longest_streak, v_new_current);
    v_new_total_days := v_streak.total_active_days + 1;
    UPDATE public.streaks
      SET current_streak = v_new_current,
          longest_streak = v_new_longest,
          total_active_days = v_new_total_days,
          last_active = v_tx_date
      WHERE user_id = NEW.user_id;
  ELSIF v_tx_date > v_streak.last_active + 1 THEN
    v_new_current := 1;
    v_new_longest := GREATEST(v_streak.longest_streak, 1);
    v_new_total_days := v_streak.total_active_days + 1;
    UPDATE public.streaks
      SET current_streak = v_new_current,
          longest_streak = v_new_longest,
          total_active_days = v_new_total_days,
          last_active = v_tx_date
      WHERE user_id = NEW.user_id;
  ELSE
    -- Backdated entry does not break an existing newer streak
    v_new_current := v_streak.current_streak;
    v_new_longest := v_streak.longest_streak;
  END IF;

  -- Aggregate real user metrics for badge unlocks
  SELECT
    COALESCE(SUM(CASE WHEN type = 'saving' THEN amount ELSE 0 END), 0),
    COUNT(*)
    INTO v_total_savings, v_total_tx_count
    FROM public.transactions
    WHERE user_id = NEW.user_id;

  SELECT COALESCE(savings_target, 0)
    INTO v_target
    FROM public.profiles
    WHERE id = NEW.user_id;

  IF NEW.type = 'saving' THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'first_save')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_total_tx_count >= 10 THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'consistent_10')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_new_current >= 3 THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'streak_3')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_new_current >= 7 THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'streak_7')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_new_current >= 30 THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'streak_30')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_total_savings >= 1000000 THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'saver_1m')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_target > 0 AND v_total_savings >= (v_target * 0.5) THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'target_50')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  IF v_target > 0 AND v_total_savings >= v_target THEN
    INSERT INTO public.user_badges (user_id, badge_code)
    VALUES (NEW.user_id, 'target_100')
    ON CONFLICT (user_id, badge_code) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_transactions_gamification ON public.transactions;
CREATE TRIGGER trg_transactions_gamification
  AFTER INSERT ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_transaction_gamification();

-- 2. Efficient single-round-trip Financial Summary & Monthly Insights RPC
-- SECURITY INVOKER ensures PostgreSQL RLS is enforced on every query inside.
CREATE OR REPLACE FUNCTION public.get_financial_summary(p_months INT DEFAULT 6)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_months INT := LEAST(GREATEST(COALESCE(p_months, 6), 1), 12);
  v_total_savings NUMERIC(14, 2);
  v_total_expenses NUMERIC(14, 2);
  v_month_savings NUMERIC(14, 2);
  v_month_expenses NUMERIC(14, 2);
  v_monthly JSONB;
  v_categories JSONB;
  v_month_start TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_month_start := date_trunc('month', NOW() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta';

  SELECT
    COALESCE(SUM(CASE WHEN type = 'saving' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN type = 'saving' AND occurred_at >= v_month_start THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN type = 'expense' AND occurred_at >= v_month_start THEN amount ELSE 0 END), 0)
    INTO v_total_savings, v_total_expenses, v_month_savings, v_month_expenses
    FROM public.transactions
    WHERE user_id = v_uid;

  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (NOW() AT TIME ZONE 'Asia/Jakarta')) - ((v_months - 1) || ' months')::INTERVAL,
      date_trunc('month', (NOW() AT TIME ZONE 'Asia/Jakarta')),
      '1 month'::INTERVAL
    )::DATE AS month_date
  ),
  agg AS (
    SELECT
      date_trunc('month', (occurred_at AT TIME ZONE 'Asia/Jakarta'))::DATE AS month_date,
      COALESCE(SUM(CASE WHEN type = 'saving' THEN amount ELSE 0 END), 0) AS savings,
      COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expenses
    FROM public.transactions
    WHERE user_id = v_uid
      AND occurred_at >= (
        date_trunc('month', (NOW() AT TIME ZONE 'Asia/Jakarta')) - ((v_months - 1) || ' months')::INTERVAL
      ) AT TIME ZONE 'Asia/Jakarta'
    GROUP BY 1
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'month', to_char(m.month_date, 'YYYY-MM'),
        'savings', COALESCE(a.savings, 0),
        'expenses', COALESCE(a.expenses, 0)
      )
      ORDER BY m.month_date ASC
    ),
    '[]'::jsonb
  )
  INTO v_monthly
  FROM months m
  LEFT JOIN agg a ON a.month_date = m.month_date;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'category', category,
        'type', type,
        'total', total_amount,
        'count', tx_count
      )
      ORDER BY total_amount DESC
    ),
    '[]'::jsonb
  )
  INTO v_categories
  FROM (
    SELECT
      category,
      type,
      SUM(amount) AS total_amount,
      COUNT(*) AS tx_count
    FROM public.transactions
    WHERE user_id = v_uid
      AND occurred_at >= v_month_start
    GROUP BY category, type
  ) c;

  RETURN jsonb_build_object(
    'total_savings', v_total_savings,
    'total_expenses', v_total_expenses,
    'month_savings', v_month_savings,
    'month_expenses', v_month_expenses,
    'monthly_trends', v_monthly,
    'category_breakdown', v_categories
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_financial_summary(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_financial_summary(INT) TO authenticated;
