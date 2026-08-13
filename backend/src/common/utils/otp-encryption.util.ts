import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

/**
 * Minimal AES-256-GCM helper backing the Admin OTP-reveal feature only.
 * Authenticated encryption (GCM) so a tampered/corrupted ciphertext fails
 * decryption loudly rather than silently returning garbage.
 *
 * Never used by normal OTP request/verify — those continue to use only
 * bcrypt (see AuthService.requestOtp / _verifyAuthOtp). This exists solely
 * so an authorized admin can decrypt a still-active code to manually relay
 * it when the SMS never reached the handset.
 */
const ALGORITHM = 'aes-256-gcm';
/** NIST-recommended IV length for GCM. */
const IV_LENGTH_BYTES = 12;
const KEY_LENGTH_BYTES = 32;

export class OtpEncryptionKeyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'OtpEncryptionKeyError';
  }
}

export class OtpDecryptionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'OtpDecryptionError';
  }
}

export interface EncryptedOtp {
  ciphertext: string;
  iv: string;
  tag: string;
}

/**
 * OTP_ADMIN_ENCRYPTION_KEY must decode to exactly 32 bytes — accepted as
 * either 64 hex characters or standard base64. Throws OtpEncryptionKeyError
 * (never a raw crypto exception) so callers can decide how to degrade.
 */
function loadKey(rawKey: string | undefined | null): Buffer {
  if (!rawKey) {
    throw new OtpEncryptionKeyError(
      'OTP_ADMIN_ENCRYPTION_KEY is not configured.',
    );
  }

  const key = /^[0-9a-fA-F]{64}$/.test(rawKey)
    ? Buffer.from(rawKey, 'hex')
    : Buffer.from(rawKey, 'base64');

  if (key.length !== KEY_LENGTH_BYTES) {
    throw new OtpEncryptionKeyError(
      'OTP_ADMIN_ENCRYPTION_KEY must decode to exactly 32 bytes (64 hex characters, or base64).',
    );
  }
  return key;
}

/** Encrypts one OTP code. Throws OtpEncryptionKeyError if the key is missing/malformed. */
export function encryptOtp(
  plaintext: string,
  rawKey: string | undefined | null,
): EncryptedOtp {
  const key = loadKey(rawKey);
  const iv = randomBytes(IV_LENGTH_BYTES);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();

  return {
    ciphertext: encrypted.toString('base64'),
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
  };
}

/**
 * Decrypts one OTP code. Throws OtpEncryptionKeyError (bad/missing key) or
 * OtpDecryptionError (wrong key, or tampered/corrupted ciphertext — GCM's
 * auth tag check fails) — never a raw Node crypto exception, so callers can
 * log/report safely without leaking library internals.
 */
export function decryptOtp(
  data: EncryptedOtp,
  rawKey: string | undefined | null,
): string {
  const key = loadKey(rawKey);

  try {
    const decipher = createDecipheriv(
      ALGORITHM,
      key,
      Buffer.from(data.iv, 'base64'),
    );
    decipher.setAuthTag(Buffer.from(data.tag, 'base64'));
    const decrypted = Buffer.concat([
      decipher.update(Buffer.from(data.ciphertext, 'base64')),
      decipher.final(),
    ]);
    return decrypted.toString('utf8');
  } catch (err) {
    throw new OtpDecryptionError(
      `Failed to decrypt OTP: ${(err as Error).message}`,
    );
  }
}
