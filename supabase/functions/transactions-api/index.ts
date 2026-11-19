import { handleCorsPreflight } from '../_shared/cors.ts';
import { jsonError, jsonOk } from '../_shared/errors.ts';
import { requireAuthenticatedUser } from '../_shared/supabase.ts';

const ALLOWED_TYPES = new Set(['saving', 'expense', 'income']);
const ALLOWED_CATEGORIES = new Set([
  // Saving categories
  'emergency_fund',
  'main_goal',
  'investment',
  'daily_saving',
  'bonus',
  // Expense categories (includes PRD Section 18 example "food")
  'food',
  'transport',
  'bills',
  'shopping',
  'entertainment',
  'health',
  'other',
]);

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function sanitizeText(raw: unknown, maxLen: number): string | null {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.replace(/[\u0000-\u001F\u007F<>]/g, '').trim();
  if (!cleaned) return null;
  return cleaned.slice(0, maxLen);
}

/**
 * Implements PRD Section 18:
 * POST /api/v1/transaction (via Edge Function `transactions-api`)
 * Input: { "amount": 50000, "category": "food", "type": "expense", "note": "...", "client_id": "uuid" }
 * Returns: 201 Created with created/idempotent transaction row.
 */
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
      return jsonError(400, 'INVALID_JSON', 'Body permintaan harus berupa JSON yang valid.');
    }

    const amount = Number(body.amount);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 999_999_999_999.99) {
      return jsonError(400, 'INVALID_AMOUNT', 'Nominal transaksi harus lebih dari 0.');
    }

    let type = typeof body.type === 'string' ? body.type.trim().toLowerCase() : 'expense';
    if (!ALLOWED_TYPES.has(type)) {
      return jsonError(400, 'INVALID_TYPE', 'Tipe transaksi harus saving, income, atau expense.');
    }
    if (type === 'income') {
      type = 'saving';
    }

    const category = typeof body.category === 'string' ? body.category.trim().toLowerCase() : '';
    if (!ALLOWED_CATEGORIES.has(category)) {
      return jsonError(400, 'INVALID_CATEGORY', 'Kategori transaksi tidak valid.');
    }

    const note = sanitizeText(body.note, 140);

    let clientId: string | null = null;
    if (body.client_id !== undefined && body.client_id !== null) {
      if (typeof body.client_id !== 'string' || !UUID_REGEX.test(body.client_id)) {
        return jsonError(400, 'INVALID_CLIENT_ID', 'Format client_id harus UUID yang valid.');
      }
      clientId = body.client_id.toLowerCase();
    }

    let occurredAt = new Date().toISOString();
    if (typeof body.occurred_at === 'string') {
      const parsed = new Date(body.occurred_at);
      if (Number.isNaN(parsed.getTime())) {
        return jsonError(400, 'INVALID_DATE', 'Format tanggal transaksi tidak valid.');
      }
      occurredAt = parsed.toISOString();
    }

    // Idempotency check for duplicate-submission / offline sync retry safety
    if (clientId) {
      const { data: existing } = await auth.userClient
        .from('transactions')
        .select('*')
        .eq('client_id', clientId)
        .maybeSingle();

      if (existing) {
        return jsonOk(200, { transaction: existing, deduplicated: true });
      }
    }

    const { data: created, error: insertError } = await auth.userClient
      .from('transactions')
      .insert({
        user_id: auth.user.id,
        client_id: clientId,
        type,
        amount: Math.round(amount * 100) / 100,
        category,
        note,
        occurred_at: occurredAt,
      })
      .select('*')
      .single();

    if (insertError) {
      return jsonError(400, 'TRANSACTION_CREATE_FAILED', 'Gagal menyimpan transaksi.');
    }

    return jsonOk(201, { transaction: created, deduplicated: false });
  } catch {
    return jsonError(500, 'INTERNAL_ERROR', 'Terjadi kesalahan pada server.');
  }
});
