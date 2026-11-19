import { argon2id } from 'npm:@noble/hashes@1.7.1/argon2';
import { encodeBase64, decodeBase64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';

// OWASP-aligned Argon2id parameters balancing security and Edge Function latency
const ARGON2_MEMORY_KIB = 19456; // 19 MiB
const ARGON2_ITERATIONS = 2;
const ARGON2_PARALLELISM = 1;
const ARGON2_DK_LEN = 32;
const SALT_LEN = 16;

const encoder = new TextEncoder();

export function isValidSixDigitPin(pin: unknown): pin is string {
  return typeof pin === 'string' && /^\d{6}$/.test(pin);
}

/**
 * Hashes a 6-digit PIN with Argon2id and a CSPRNG 16-byte salt.
 * Returns PHC string format: $argon2id$v=19$m=...,t=...,p=...$<salt>$<hash>
 */
export function hashPinArgon2id(pin: string): string {
  const salt = new Uint8Array(SALT_LEN);
  crypto.getRandomValues(salt);

  const hash = argon2id(encoder.encode(pin), salt, {
    m: ARGON2_MEMORY_KIB,
    t: ARGON2_ITERATIONS,
    p: ARGON2_PARALLELISM,
    dkLen: ARGON2_DK_LEN,
  });

  const saltB64 = encodeBase64(salt).replace(/=+$/, '');
  const hashB64 = encodeBase64(hash).replace(/=+$/, '');

  return `$argon2id$v=19$m=${ARGON2_MEMORY_KIB},t=${ARGON2_ITERATIONS},p=${ARGON2_PARALLELISM}$${saltB64}$${hashB64}`;
}

/**
 * Constant-time verification of a PIN against a stored PHC Argon2id hash.
 */
export function verifyPinArgon2id(pin: string, phcHash: string): boolean {
  const parts = phcHash.split('$');
  if (parts.length !== 6 || parts[1] !== 'argon2id') {
    return false;
  }

  const paramsSegment = parts[3];
  const saltB64 = parts[4];
  const expectedHashB64 = parts[5];

  const paramMap = new Map<string, number>();
  for (const kv of paramsSegment.split(',')) {
    const [k, v] = kv.split('=');
    const parsed = Number(v);
    if (!k || !Number.isInteger(parsed) || parsed <= 0) {
      return false;
    }
    paramMap.set(k, parsed);
  }

  const m = paramMap.get('m');
  const t = paramMap.get('t');
  const p = paramMap.get('p');
  if (!m || !t || !p || m > 65536 || t > 10 || p > 4) {
    return false;
  }

  const salt = decodeBase64(padBase64(saltB64));
  const expectedHash = decodeBase64(padBase64(expectedHashB64));

  const computedHash = argon2id(encoder.encode(pin), salt, {
    m,
    t,
    p,
    dkLen: expectedHash.length,
  });

  return constantTimeEqual(computedHash, expectedHash);
}

function padBase64(input: string): string {
  const remainder = input.length % 4;
  if (remainder === 0) return input;
  return input + '='.repeat(4 - remainder);
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}
