import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ComplaintIssueType } from '@prisma/client';
import { CreateBookingComplaintDto } from './dto/create-booking-complaint.dto';

describe('CreateBookingComplaintDto', () => {
  async function errors(body: object) {
    return validate(plainToInstance(CreateBookingComplaintDto, body));
  }

  it('rejects no issue types', async () => {
    await expect(errors({ issueTypes: [] })).resolves.not.toHaveLength(0);
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
        otherText: 'More context',
      }),
    ).resolves.toHaveLength(0);
  });
});
