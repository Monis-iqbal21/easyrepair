import { randomBytes } from 'crypto';
import {
  decryptOtp,
  encryptOtp,
  OtpDecryptionError,
  OtpEncryptionKeyError,
} from './otp-encryption.util';

const KEY_HEX = randomBytes(32).toString('hex');
const OTHER_KEY_HEX = randomBytes(32).toString('hex');
const KEY_BASE64 = randomBytes(32).toString('base64');

describe('otp-encryption.util', () => {
  // #12 encryption/decryption works
  it('decrypts back to the exact plaintext OTP that was encrypted (hex key)', () => {
    const encrypted = encryptOtp('123456', KEY_HEX);
    const decrypted = decryptOtp(encrypted, KEY_HEX);
    expect(decrypted).toBe('123456');
  });

  it('works with a base64-encoded 32-byte key too', () => {
    const encrypted = encryptOtp('987654', KEY_BASE64);
    const decrypted = decryptOtp(encrypted, KEY_BASE64);
    expect(decrypted).toBe('987654');
  });

  it('produces a different ciphertext/iv on every call (random IV)', () => {
    const a = encryptOtp('111111', KEY_HEX);
    const b = encryptOtp('111111', KEY_HEX);
    expect(a.ciphertext).not.toBe(b.ciphertext);
    expect(a.iv).not.toBe(b.iv);
  });

  // #13 wrong key / decryption failure handled safely
  it('throws OtpDecryptionError (not a raw crypto exception) when decrypting with the wrong key', () => {
    const encrypted = encryptOtp('555555', KEY_HEX);
    expect(() => decryptOtp(encrypted, OTHER_KEY_HEX)).toThrow(
      OtpDecryptionError,
    );
  });

  it('throws OtpDecryptionError on a tampered ciphertext (GCM auth tag check fails)', () => {
    const encrypted = encryptOtp('555555', KEY_HEX);
    const tampered = {
      ...encrypted,
      ciphertext: Buffer.from('tampered-bytes-xx').toString('base64'),
    };
    expect(() => decryptOtp(tampered, KEY_HEX)).toThrow(OtpDecryptionError);
  });

  it('throws OtpEncryptionKeyError when no key is configured', () => {
    expect(() => encryptOtp('123456', undefined)).toThrow(
      OtpEncryptionKeyError,
    );
    expect(() => decryptOtp(encryptOtp('123456', KEY_HEX), undefined)).toThrow(
      OtpEncryptionKeyError,
    );
  });

  it('throws OtpEncryptionKeyError when the key does not decode to 32 bytes', () => {
    expect(() => encryptOtp('123456', 'too-short')).toThrow(
      OtpEncryptionKeyError,
    );
  });
});
