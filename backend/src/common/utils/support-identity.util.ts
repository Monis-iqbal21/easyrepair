/**
 * Identity test for the "HandyGo Support" system account.
 *
 * A pure function so both SupportUserService (which provisions the account)
 * and AuthService (which must refuse to sign into it) share one definition
 * and cannot drift apart. Kept out of ChatModule so AuthModule does not have
 * to depend on it.
 */

/**
 * Reduces a phone to its national significant number: digits only, last 10.
 *
 * Comparing the last 10 digits is what makes `+92…`, `0092…`, `92…` and `0…`
 * forms of the same Pakistani mobile equal. Stripping leading zeros instead
 * would be wrong here — the reserved support number is itself zero-heavy, so
 * prefix-stripping cannot tell its variants apart.
 */
function nationalSignificant(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  return digits.length > 10 ? digits.slice(-10) : digits;
}

/**
 * True when [phone] is the reserved support account number.
 *
 * The support account exists only to own support conversations and to be the
 * sender of admin replies. It has no credentials, and every authentication
 * path (password login, OTP request, OTP verification, password reset) must
 * reject it outright.
 */
export function isSupportPhone(
  phone: string | null | undefined,
  supportPhone: string | null | undefined,
): boolean {
  if (!phone || !supportPhone) return false;
  const a = nationalSignificant(phone);
  const b = nationalSignificant(supportPhone);
  if (!a || !b) return false;
  return a === b;
}
