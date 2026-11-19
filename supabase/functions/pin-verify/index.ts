import { handleCorsPreflight } from '../_shared/cors.ts';
import { jsonError, jsonOk } from '../_shared/errors.ts';
import { requireAuthenticatedUser } from '../_shared/supabase.ts';
import { isValidSixDigitPin, verifyPinArgon2id } from '../_shared/argon2.ts';

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

    const pin = body.pin;
    if (!isValidSixDigitPin(pin)) {
      return jsonError(400, 'INVALID_PIN_FORMAT', 'PIN harus terdiri dari 6 digit angka.');
    }

    const { data: profile, error: fetchError } = await auth.adminClient
      .from('profiles')
      .select('pin_hash, pin_failed_attempts, pin_locked_until')
      .eq('id', auth.user.id)
      .maybeSingle();

    if (fetchError) {
      console.error('Error fetching profile in pin-verify:', fetchError);
    }

    if (!profile) {
      return jsonError(404, 'PROFILE_NOT_FOUND', 'Profil pengguna tidak ditemukan.');
    }

    if (!profile.pin_hash) {
      return jsonError(409, 'PIN_NOT_CONFIGURED', 'PIN belum diatur. Silakan buat PIN terlebih dahulu.');
    }

    const now = new Date();
    if (profile.pin_locked_until && new Date(profile.pin_locked_until) > now) {
      return jsonError(
        429,
        'PIN_LOCKED',
        'Akses PIN terkunci sementara karena terlalu banyak percobaan salah.',
        { locked_until: profile.pin_locked_until },
      );
    }

    const isMatch = verifyPinArgon2id(pin, profile.pin_hash);
    if (!isMatch) {
      const nextAttempts = (profile.pin_failed_attempts ?? 0) + 1;
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

      await auth.adminClient.from('audit_logs').insert({
        user_id: auth.user.id,
        action: lockedUntil ? 'PIN_LOCKOUT' : 'PIN_VERIFY_FAILED',
        metadata: { attempts: nextAttempts },
      });

      return jsonError(
        lockedUntil ? 429 : 401,
        lockedUntil ? 'PIN_LOCKED' : 'INVALID_PIN',
        lockedUntil
          ? 'Terlalu banyak percobaan salah. Coba lagi setelah 15 menit.'
          : 'PIN tidak sesuai. Silakan coba lagi.',
        {
          remaining_attempts: Math.max(0, MAX_FAILED_ATTEMPTS - nextAttempts),
          locked_until: lockedUntil,
        },
      );
    }

    if ((profile.pin_failed_attempts ?? 0) > 0 || profile.pin_locked_until !== null) {
      await auth.adminClient
        .from('profiles')
        .update({
          pin_failed_attempts: 0,
          pin_locked_until: null,
        })
        .eq('id', auth.user.id);
    }

    return jsonOk(200, {
      verified: true,
      verified_at: now.toISOString(),
    });
  } catch {
    return jsonError(500, 'INTERNAL_ERROR', 'Terjadi kesalahan saat verifikasi PIN.');
  }
});
