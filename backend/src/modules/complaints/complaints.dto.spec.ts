import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ComplaintIssueType } from '@prisma/client';
import {
  COMPLAINT_DETAILS_MIN_LENGTH,
  CreateBookingComplaintDto,
} from './dto/create-booking-complaint.dto';

describe('CreateBookingComplaintDto', () => {
  async function errors(body: object) {
    return validate(plainToInstance(CreateBookingComplaintDto, body));
  }

  const DETAILS = 'Ustaad left the job half finished';

  it('rejects no issue types', async () => {
    await expect(
      errors({ issueTypes: [], otherText: DETAILS }),
    ).resolves.not.toHaveLength(0);
  });

  it('rejects OTHER without otherText', async () => {
    await expect(
      errors({ issueTypes: [ComplaintIssueType.OTHER] }),
    ).resolves.not.toHaveLength(0);
  });

  it('accepts OTHER with text and multiple issue types', async () => {
    await expect(
      errors({
        issueTypes: [ComplaintIssueType.OTHER, ComplaintIssueType.WORK_QUALITY],
        otherText: DETAILS,
      }),
    ).resolves.toHaveLength(0);
  });

  // ── FIX 4: details are required for EVERY complaint, not only OTHER ──────

  it('rejects a ticked box with no details at all', async () => {
    await expect(
      errors({ issueTypes: [ComplaintIssueType.WORK_QUALITY] }),
    ).resolves.not.toHaveLength(0);
  });

  it('rejects whitespace-only details', async () => {
    await expect(
      errors({
        issueTypes: [ComplaintIssueType.WORK_QUALITY],
        otherText: '            ',
      }),
    ).resolves.not.toHaveLength(0);
  });

  it('rejects details shorter than the minimum', async () => {
    await expect(
      errors({
        issueTypes: [ComplaintIssueType.WORK_QUALITY],
        otherText: 'a'.repeat(COMPLAINT_DETAILS_MIN_LENGTH - 1),
      }),
    ).resolves.not.toHaveLength(0);
  });

  it('accepts details at exactly the minimum length', async () => {
    await expect(
      errors({
        issueTypes: [ComplaintIssueType.WORK_QUALITY],
        otherText: 'a'.repeat(COMPLAINT_DETAILS_MIN_LENGTH),
      }),
    ).resolves.toHaveLength(0);
  });

  it('rejects details over the maximum length', async () => {
    await expect(
      errors({
        issueTypes: [ComplaintIssueType.WORK_QUALITY],
        otherText: 'a'.repeat(2001),
      }),
    ).resolves.not.toHaveLength(0);
  });
});
