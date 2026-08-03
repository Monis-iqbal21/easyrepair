import {
  assertFullyPopulated,
  assertNoDevanagari,
} from './agreement-validation.util';
import { TradeCode } from './agreement-source.types';

/**
 * Turns an approved SOURCE document (a template with fill-in blanks) into the
 * personalized ACCEPTED document that is hashed, rendered to PDF and sealed
 * into an immutable acceptance record.
 *
 * Rules this file exists to enforce:
 *   - Legal wording is never rewritten. Only `Label: ____` blanks are filled.
 *   - No blank may survive. A missing MANDATORY value aborts generation; a
 *     genuinely non-applicable one prints a controlled "Not applicable".
 *   - System values (acceptance id, timestamps, hashes) come from the server,
 *     never from the client.
 */

/** Printed where a field genuinely does not apply — never an empty blank. */
export const NOT_APPLICABLE = 'Not applicable';

/** Ustaad-supplied and system-resolved values available to the filler. */
export interface PersonalizationData {
  // ── Identity (from the authenticated profile; never re-typed) ────────────
  fullLegalName: string;
  fatherName: string | null;
  cnicNumber: string;
  dateOfBirth: string | null;
  residentialAddress: string | null;
  registeredMobile: string;
  ustaadAccountId: string;
  mainTrade: string;
  approvedServiceTags: string | null;
  emergencyContact: string | null;
  verificationProvider: string | null;
  verificationRequestDate: string | null;
  verificationRequestReference: string | null;

  // ── Server-generated (client values are never trusted) ───────────────────
  acceptanceId: string;
  acceptedAtIso: string;
  sourceDocumentHash: string;
  deviceSessionIpReference: string;
}

/**
 * Blank labels, exactly as they appear in the approved documents, mapped to
 * the value that fills them.
 *
 * `mandatory: true` means generation FAILS if the value is missing — better a
 * blocked submission with a clear error than a legal document with a hole in
 * it. `mandatory: false` prints [NOT_APPLICABLE] when absent.
 */
type FieldResolver = (d: PersonalizationData) => string | null;

interface BlankSpec {
  resolve: FieldResolver;
  mandatory: boolean;
  /** Profile field to point the Ustaad at when a mandatory value is missing. */
  profileField: string;
}

const BLANKS: Record<string, BlankSpec> = {
  // Identity — the same value appears under several approved label wordings.
  'CNIC ke mutabiq poora legal naam': {
    resolve: (d) => d.fullLegalName,
    mandatory: true,
    profileField: 'fullLegalName',
  },
  'Ustaad ka Legal Naam': {
    resolve: (d) => d.fullLegalName,
    mandatory: true,
    profileField: 'fullLegalName',
  },
  'Walid ka naam': {
    resolve: (d) => d.fatherName,
    mandatory: true,
    profileField: 'fatherName',
  },
  'CNIC Number': {
    resolve: (d) => d.cnicNumber,
    mandatory: true,
    profileField: 'cnicNumber',
  },
  'Date of Birth': {
    resolve: (d) => d.dateOfBirth,
    mandatory: true,
    profileField: 'dateOfBirth',
  },
  'Residential Address': {
    resolve: (d) => d.residentialAddress,
    mandatory: true,
    profileField: 'residentialAddress',
  },
  'Current Residential Address': {
    resolve: (d) => d.residentialAddress,
    mandatory: true,
    profileField: 'residentialAddress',
  },
  'Registered Mobile Number': {
    resolve: (d) => d.registeredMobile,
    mandatory: true,
    profileField: 'registeredMobile',
  },
  'Ustaad Account ID': {
    resolve: (d) => d.ustaadAccountId,
    mandatory: true,
    profileField: 'ustaadAccountId',
  },
  'Approved Main Trade': {
    resolve: (d) => d.mainTrade,
    mandatory: true,
    profileField: 'mainTrade',
  },
  'Main Trade': {
    resolve: (d) => d.mainTrade,
    mandatory: true,
    profileField: 'mainTrade',
  },
  'Emergency Contact': {
    resolve: (d) => d.emergencyContact,
    mandatory: false,
    profileField: 'emergencyContact',
  },

  // Trade service tags — one approved label per schedule.
  'Approved Electrician Service Tags': {
    resolve: (d) => d.approvedServiceTags,
    mandatory: false,
    profileField: 'approvedServiceTags',
  },
  'Approved Plumber Service Tags': {
    resolve: (d) => d.approvedServiceTags,
    mandatory: false,
    profileField: 'approvedServiceTags',
  },
  'Approved AC Service Tags': {
    resolve: (d) => d.approvedServiceTags,
    mandatory: false,
    profileField: 'approvedServiceTags',
  },
  'Approved Carpenter Service Tags': {
    resolve: (d) => d.approvedServiceTags,
    mandatory: false,
    profileField: 'approvedServiceTags',
  },

  // Background verification — supplied only once a check has been raised.
  'Verification Provider/Agency': {
    resolve: (d) => d.verificationProvider,
    mandatory: false,
    profileField: 'verificationProvider',
  },
  'Request Date': {
    resolve: (d) => d.verificationRequestDate,
    mandatory: false,
    profileField: 'verificationRequestDate',
  },
  'Verification Request Reference': {
    resolve: (d) => d.verificationRequestReference,
    mandatory: false,
    profileField: 'verificationRequestReference',
  },
  'Provider Request Reference': {
    resolve: (d) => d.verificationRequestReference,
    mandatory: false,
    profileField: 'verificationRequestReference',
  },

  // System-generated. The three documents word these differently but they
  // carry the same server-side values.
  'Electronic Acceptance Date/Time': {
    resolve: (d) => d.acceptedAtIso,
    mandatory: true,
    profileField: 'system',
  },
  'Consent Date/Time': {
    resolve: (d) => d.acceptedAtIso,
    mandatory: true,
    profileField: 'system',
  },
  'Acknowledgement Date/Time': {
    resolve: (d) => d.acceptedAtIso,
    mandatory: true,
    profileField: 'system',
  },
  'Unique Acceptance ID': {
    resolve: (d) => d.acceptanceId,
    mandatory: true,
    profileField: 'system',
  },
  'Unique Consent ID': {
    resolve: (d) => d.acceptanceId,
    mandatory: true,
    profileField: 'system',
  },
  'Unique Acknowledgement ID': {
    resolve: (d) => d.acceptanceId,
    mandatory: true,
    profileField: 'system',
  },
  'Document Hash/Immutable Snapshot Reference': {
    resolve: (d) => d.sourceDocumentHash,
    mandatory: true,
    profileField: 'system',
  },
  'Document Snapshot/Hash Reference': {
    resolve: (d) => d.sourceDocumentHash,
    mandatory: true,
    profileField: 'system',
  },
  'Consent Document Hash/Snapshot Reference': {
    resolve: (d) => d.sourceDocumentHash,
    mandatory: true,
    profileField: 'system',
  },
  'Privacy Notice Hash/Snapshot Reference': {
    resolve: (d) => d.sourceDocumentHash,
    mandatory: true,
    profileField: 'system',
  },
  'Device/Session/IP Reference': {
    resolve: (d) => d.deviceSessionIpReference,
    mandatory: true,
    profileField: 'system',
  },

  // Counter-signed by HandyGo after review, so it is legitimately empty at
  // Ustaad acceptance time — printed as a controlled value, never a blank.
  'Authorized HandyGo Reviewer': {
    resolve: () => null,
    mandatory: false,
    profileField: 'system',
  },
};

/** `Label: _______` — the only shape this filler touches. */
const BLANK_LINE = /^(\s*)([^:\n]{3,70}?):(\s*)_{3,}\s*$/;

/** "… available ki gayi: □ Haan □ Nahi" — ticked because the PDF IS provided. */
const AVAILABILITY_LINE = /^(\s*)(.+available ki gayi):\s*□\s*Haan\s*□\s*Nahi\s*$/;

export class MissingAgreementDataError extends Error {
  constructor(
    readonly missingFields: { label: string; profileField: string }[],
  ) {
    super(
      `Cannot generate accepted agreement — missing required profile data: ${missingFields
        .map((f) => f.profileField)
        .join(', ')}`,
    );
    this.name = 'MissingAgreementDataError';
  }
}

export interface PersonalizationResult {
  text: string;
  /** Labels filled with a real value, for auditing what was populated. */
  filled: string[];
  /** Labels printed as "Not applicable". */
  notApplicable: string[];
}

/**
 * Fills every blank in [sourceText].
 *
 * Throws [MissingAgreementDataError] listing the exact profile fields to fix
 * when a mandatory value is absent — the caller surfaces those to the Ustaad
 * rather than generating a document with holes.
 */
export function personalizeAgreement(
  sourceText: string,
  data: PersonalizationData,
): PersonalizationResult {
  const missing: { label: string; profileField: string }[] = [];
  const filled: string[] = [];
  const notApplicable: string[] = [];

  const lines = sourceText.split('\n').map((line) => {
    const availability = line.match(AVAILABILITY_LINE);
    if (availability) {
      // The accepted PDF is generated and made available in the same
      // transaction, so this is affirmatively true.
      return `${availability[1]}${availability[2]}: Haan`;
    }

    const match = line.match(BLANK_LINE);
    if (!match) return line;

    const [, indent, rawLabel, gap] = match;
    const label = rawLabel.trim();
    const spec = BLANKS[label];

    if (!spec) {
      // An unrecognised blank must never be silently left in place — that is
      // exactly how a document ships with a hole. Treat it as missing data.
      missing.push({ label, profileField: `unmapped:${label}` });
      return line;
    }

    const value = spec.resolve(data)?.toString().trim() || null;
    if (value) {
      filled.push(label);
      return `${indent}${rawLabel}:${gap || ' '}${value}`;
    }

    if (spec.mandatory) {
      missing.push({ label, profileField: spec.profileField });
      return line;
    }

    notApplicable.push(label);
    return `${indent}${rawLabel}:${gap || ' '}${NOT_APPLICABLE}`;
  });

  if (missing.length > 0) {
    throw new MissingAgreementDataError(missing);
  }

  const text = lines.join('\n');

  // Belt and braces: the accepted copy is about to be hashed and sealed.
  assertFullyPopulated(text, 'personalized agreement');
  assertNoDevanagari(text, 'personalized agreement');

  return { text, filled, notApplicable };
}

/**
 * Formats the approved service tags for the schedule of [trade].
 * Kept here so the list an Ustaad is bound by is rendered one way only.
 */
export function formatServiceTags(
  tags: readonly string[] | null | undefined,
  _trade: TradeCode | null,
): string | null {
  if (!tags || tags.length === 0) return null;
  return tags.map((t) => t.trim()).filter(Boolean).join(', ') || null;
}
