/**
 * Accepted raw shapes for a Pakistani mobile number: 03XXXXXXXXX, 3XXXXXXXXX,
 * 923XXXXXXXXX, +923XXXXXXXXX, 00923XXXXXXXXX (any amount of whitespace is
 * tolerated and stripped before matching).
 */
const PAKISTANI_MOBILE_PATTERN = /^(\+92|0092|92|0)?3[0-9]{9}$/;

/**
 * Normalizes any accepted raw Pakistani mobile number to E.164 (+923XXXXXXXXX).
 * Returns null if the input isn't a recognizable Pakistani mobile number —
 * callers must treat that as a validation failure, not fall back to the raw
 * input.
 */
export function normalizePakistaniPhone(raw: string): string | null {
  const trimmed = raw.trim().replace(/[\s-]/g, '');
  if (!PAKISTANI_MOBILE_PATTERN.test(trimmed)) return null;

  const digits = trimmed.replace(/\D/g, '');
  // digits is one of: 3XXXXXXXXX (10), 03XXXXXXXXX (11),
  // 923XXXXXXXXX (12), 00923XXXXXXXXX (14)
  if (digits.startsWith('0092')) return `+92${digits.slice(4)}`;
  if (digits.startsWith('92') && digits.length === 12) return `+${digits}`;
  if (digits.startsWith('0') && digits.length === 11) return `+92${digits.slice(1)}`;
  return `+92${digits}`; // bare 3XXXXXXXXX (10 digits)
}

/**
 * Every historical format a phone number stored before this normalization was
 * introduced could plausibly be sitting in the `phone` column as — used to
 * find existing accounts regardless of which format they were created with,
 * without ever treating two formats of the same number as different users.
 */
export function phoneLookupVariants(normalized: string): string[] {
  const local = normalized.replace(/^\+92/, '0'); // 03XXXXXXXXX
  const noPlus = normalized.replace(/^\+/, ''); // 923XXXXXXXXX
  const zeroZero = normalized.replace(/^\+92/, '0092'); // 00923XXXXXXXXX
  return [normalized, local, noPlus, zeroZero];
}
