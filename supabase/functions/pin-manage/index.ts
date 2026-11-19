import { handleCorsPreflight } from '../_shared/cors.ts';
import { jsonError, jsonOk } from '../_shared/errors.ts';
import { requireAuthenticatedUser } from '../_shared/supabase.ts';
import { hashPinArgon2id, isValidSixDigitPin, verifyPinArgon2id } from '../_shared/argon2.ts';

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 15;

Deno.serve(async (req: Request) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== 'POST') {
    return jsonError(405, 'METHOD_NOT_ALLOWED', 'Hanya metode POST yang diizinkan.');
  }

  try {
    const auth = await requireAuthenticatedUser(req);
    if (!auth) {
      return jsonError(401, 'UNAUTHORIZED', 'Sesi tidak valid. Silakan masuk kembali.');
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(400, 'INVALID_JSON', 'Format permintaan tidak valid.');
    }

    const newPin = body.new_pin;
    const currentPin = body.current_pin;

    if (!isValidSixDigitPin(newPin)) {
      return jsonError(400, 'INVALID_PIN_FORMAT', 'PIN harus terdiri dari tepat 6 digit angka.');
    }

    // Reject trivially weak sequential/repeated PINs (e.g. 000000, 123456)
    if (/^(\d)\1{5}$/.test(newPin) || newPin === '123456' || newPin === '654321') {
      return jsonError(
        400,
        'WEAK_PIN',
        'PIN terlalu mudah ditebak. Gunakan kombinasi angka yang lebih aman.',
      );
    }

    const { data: profile, error: fetchError } = await auth.adminClient
      .from('profiles')
      .select('pin_hash, pin_failed_attempts, pin_locked_until')
      .eq('id', auth.user.id)
      .maybeSingle();

    if (fetchError) {
      console.error('Error fetching profile in pin-manage:', fetchError);
    }

    let activeProfile = profile;
    if (!activeProfile) {
      // Auto-provision profile and streak if missing (e.g. user existed prior to trigger)
      const metadata = auth.user.user_metadata ?? {};
      const fullName = (metadata.full_name as string | undefined) ??
        (metadata.name as string | undefined) ??
        auth.user.email?.split('@')[0] ??
        'Pengguna';
      const avatarUrl = (metadata.avatar_url as string | undefined) ?? null;

      const { data: provisionedProfile, error: upsertErr } = await auth.adminClient
        .from('profiles')
        .upsert(
          {
            id: auth.user.id,
            email: auth.user.email ?? '',
            full_name: fullName,
            avatar_url: avatarUrl,
          },
          { onConflict: 'id' },
        )
        .select('pin_hash, pin_failed_attempts, pin_locked_until')
        .single();

      if (upsertErr) {
        console.error('Failed to auto-provision profile in pin-manage:', upsertErr);
        return jsonError(500, 'PROFILE_PROVISION_FAILED', 'Gagal menyiapkan data profil.');
      }

      await auth.adminClient
        .from('streaks')
        .upsert(
          {
            user_id: auth.user.id,
            current_streak: 0,
            longest_streak: 0,
            total_active_days: 0,
          },
          { onConflict: 'user_id' },
        );

      activeProfile = provisionedProfile;
    }

    const now = new Date();
    const isReset = Boolean(body.reset || body.is_reset);

    if (!isReset && activeProfile.pin_locked_until && new Date(activeProfile.pin_locked_until) > now) {
      return jsonError(
        429,
        'PIN_LOCKED',
        'Terlalu banyak percobaan gagal. Coba lagi dalam beberapa menit.',
        { locked_until: activeProfile.pin_locked_until },
      );
    }

    const isUpdate = Boolean(activeProfile.pin_hash) && !isReset;
    if (isUpdate) {
      if (!isValidSixDigitPin(currentPin)) {
        return jsonError(400, 'CURRENT_PIN_REQUIRED', 'PIN saat ini wajib diisi (6 digit).');
      }

      const validCurrent = verifyPinArgon2id(currentPin, activeProfile.pin_hash!);
      if (!validCurrent) {
        const nextAttempts = (activeProfile.pin_failed_attempts ?? 0) + 1;
        const lockedUntil = nextAttempts >= MAX_FAILED_ATTEMPTS
          ? new Date(now.getTime() + LOCKOUT_MINUTES * 60_000).toISOString()
          : null;

        await auth.adminClient
          .from('profiles')
          .update({
            pin_failed_attempts: nextAttempts,
            pin_locked_until: lockedUntil,
          })
          .eq('id', auth.user.id);

        return jsonError(
          lockedUntil ? 429 : 401,
          lockedUntil ? 'PIN_LOCKED' : 'INVALID_CURRENT_PIN',
          lockedUntil
            ? 'Terlalu banyak percobaan salah. Akun terkunci sementara 15 menit.'
            : 'PIN saat ini tidak sesuai.',
          {
            remaining_attempts: Math.max(0, MAX_FAILED_ATTEMPTS - nextAttempts),
            locked_until: lockedUntil,
          },
        );
      }
    }

    const pinHash = hashPinArgon2id(newPin);
    const pinSetAt = now.toISOString();

    const { error: updateError } = await auth.adminClient
      .from('profiles')
      .update({
        pin_hash: pinHash,
        pin_set_at: pinSetAt,
        pin_failed_attempts: 0,
        pin_locked_until: null,
      })
      .eq('id', auth.user.id);

    if (updateError) {
      return jsonError(500, 'PIN_SAVE_FAILED', 'Gagal menyimpan PIN. Silakan coba lagi.');
    }

    await auth.adminClient.from('audit_logs').insert({
      user_id: auth.user.id,
      action: isReset ? 'PIN_RESET' : (isUpdate ? 'PIN_UPDATED' : 'PIN_CREATED'),
      metadata: { at: pinSetAt },
    });

    return jsonOk(200, {
      success: true,
      has_pin: true,
      pin_set_at: pinSetAt,
    });
  } catch {
    return jsonError(500, 'INTERNAL_ERROR', 'Terjadi kesalahan pada server.');
  }
});
