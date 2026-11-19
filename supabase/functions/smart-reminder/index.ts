import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { jsonError, jsonOk } from '../_shared/errors.ts';

/**
 * Smart Adaptive Reminder Edge Function (PRD Section 22 & 28).
 * Triggered hourly by Supabase Cron / GitHub Actions with `x-cron-secret`.
 * Sends FCM reminders only to users who:
 *  1) Have notifications_enabled = true and a valid fcm_token
 *  2) Match the current WIB reminder_hour
 *  3) Have not recorded any transaction today (preserving their streak)
 */
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonError(405, 'METHOD_NOT_ALLOWED', 'Hanya metode POST yang diizinkan.');
  }

  const expectedSecret = Deno.env.get('CRON_SECRET');
  const providedSecret = req.headers.get('x-cron-secret');
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return jsonError(401, 'UNAUTHORIZED', 'Token cron tidak valid.');
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const fcmProjectId = Deno.env.get('FCM_PROJECT_ID');
  const fcmAccessToken = Deno.env.get('FCM_OAUTH_ACCESS_TOKEN');

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonError(500, 'CONFIG_MISSING', 'Konfigurasi Supabase belum lengkap.');
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Compute current date & hour in WIB (UTC+7)
  const nowUtc = new Date();
  const wibTime = new Date(nowUtc.getTime() + 7 * 60 * 60 * 1000);
  const currentWibHour = wibTime.getUTCHours();
  const todayWib = wibTime.toISOString().slice(0, 10);

  const { data: candidates, error } = await adminClient
    .from('profiles')
    .select('id, full_name, fcm_token, streaks(current_streak, last_active)')
    .eq('notifications_enabled', true)
    .eq('reminder_hour', currentWibHour)
    .not('fcm_token', 'is', null);

  if (error) {
    return jsonError(500, 'QUERY_FAILED', 'Gagal mengambil daftar pengingat.');
  }

  let sentCount = 0;
  let skippedCount = 0;

  for (const row of candidates ?? []) {
    const streak = Array.isArray(row.streaks) ? row.streaks[0] : row.streaks;
    if (streak?.last_active === todayWib) {
      skippedCount++;
      continue;
    }

    const currentStreak = streak?.current_streak ?? 0;
    const title = currentStreak > 0
      ? `Jaga streak ${currentStreak} harimu!`
      : 'Waktunya catat tabungan hari ini';
    const body = currentStreak > 0
      ? 'Catat transaksi dalam 5 detik supaya streak harianmu tetap menyala.'
      : 'Langkah kecil hari ini bikin target tabunganmu makin dekat.';

    if (fcmProjectId && fcmAccessToken && row.fcm_token) {
      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${fcmAccessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: row.fcm_token,
              notification: { title, body },
              data: { route: '/dashboard', action: 'quick_add' },
            },
          }),
        },
      );
      if (fcmRes.ok) {
        sentCount++;
      }
    } else {
      skippedCount++;
    }
  }

  return jsonOk(200, {
    hour_wib: currentWibHour,
    sent: sentCount,
    skipped: skippedCount,
  });
});
