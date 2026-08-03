import { TradeCode, TRADE_CODES } from './agreement-source.types';

/**
 * Maps a ServiceCategory to the trade schedule an Ustaad must accept.
 *
 * Keyed on the category's stable backend name — the same string
 * `BookingEntity.serviceCategory` carries — and NEVER on a translated or
 * UI-displayed label. Selecting a legal schedule by comparing display text
 * would mean a category rename, or an Ustaad switching app language, could
 * silently change which contract they are bound by.
 *
 * There is deliberately no default. An unmapped trade returns null, and the
 * caller must block submission with a localized error rather than fall back
 * to some other trade's schedule.
 */
const CATEGORY_NAME_TO_TRADE: Record<string, TradeCode> = {
  Electrician: 'ELECTRICIAN',
  Plumber: 'PLUMBER',
  'AC Technician': 'AC_TECHNICIAN',
  Carpenter: 'CARPENTER',
};

/** Case/whitespace-insensitive lookup, still exact on the canonical name. */
const NORMALISED = new Map<string, TradeCode>(
  Object.entries(CATEGORY_NAME_TO_TRADE).map(([name, code]) => [
    name.trim().toLowerCase(),
    code,
  ]),
);

export function isTradeCode(value: string): value is TradeCode {
  return (TRADE_CODES as readonly string[]).includes(value);
}

/**
 * The trade schedule for a service category name, or null when that category
 * has no approved schedule. Null must block submission — never substitute.
 */
export function tradeCodeForCategoryName(
  categoryName: string | null | undefined,
): TradeCode | null {
  if (!categoryName) return null;
  return NORMALISED.get(categoryName.trim().toLowerCase()) ?? null;
}

/** Categories that currently have an approved trade schedule. */
export function supportedTradeCategoryNames(): string[] {
  return Object.keys(CATEGORY_NAME_TO_TRADE);
}

/** The schedule heading expected inside that trade's document. */
export function scheduleHeadingFor(trade: TradeCode): string {
  switch (trade) {
    case 'ELECTRICIAN':
      return 'SCHEDULE E — ELECTRICIAN';
    case 'PLUMBER':
      return 'SCHEDULE P — PLUMBER';
    case 'AC_TECHNICIAN':
      return 'SCHEDULE A — AC TECHNICIAN';
    case 'CARPENTER':
      return 'SCHEDULE C — CARPENTER';
  }
}
