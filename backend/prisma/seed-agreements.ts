import { PrismaClient, AgreementType } from '@prisma/client';
import { createHash } from 'crypto';

const prisma = new PrismaClient();

const GENERAL_VERSION = 'v1.0';
const TRADE_VERSION = 'v1.0';

const GENERAL_AGREEMENT_TEXT = `HandyGo Ustaad (Worker) General Agreement — ${GENERAL_VERSION}

1. Independent Service Provider. You are registering on the HandyGo platform as an
independent Ustaad (worker). You are not an employee of HandyGo and are responsible
for your own taxes, tools, and conduct while performing jobs booked through the app.

2. Code of Conduct. You agree to behave professionally and respectfully with all
clients, to arrive within the time window you commit to, and to perform work to a
reasonable standard of skill and care.

3. Platform Fee. HandyGo deducts a platform fee from each completed booking, as
shown in the app before you accept a job. Fees may change; you will always be shown
the current fee before accepting a job.

4. Safety & Verification. You confirm that the identity documents (CNIC), selfie,
and profile information you submit are true, accurate, and belong to you. HandyGo
may verify this information and suspend your account if it is found to be false.

5. Cancellations & Conduct Violations. Repeated cancellations after acceptance,
no-shows, or client complaints of misconduct may result in warnings, temporary
suspension, or permanent removal from the platform at HandyGo's discretion.

6. Data & Privacy. Your CNIC, selfie, and other verification documents are stored
securely and are only accessible to you and HandyGo admin staff for verification
purposes. They are never shared with clients or other workers.

7. Acceptance. By checking the box and submitting your profile for review, you
confirm that you have read, understood, and agree to this General Ustaad Agreement,
and that all information you have submitted is accurate.`;

const TRADE_AGREEMENT_TEXT = (tradeName: string) =>
  `HandyGo Ustaad (Worker) Trade-Specific Agreement — ${tradeName} — ${TRADE_VERSION}

1. Trade Declaration. You confirm that ${tradeName} is your main skill/trade on
HandyGo, and that you have genuine practical experience and competence performing
${tradeName} jobs safely and to a reasonable professional standard.

2. Tools & Equipment. You are responsible for bringing your own appropriate tools
and safety equipment required to perform ${tradeName} work, unless a specific
booking states otherwise.

3. Job-Specific Safety. You agree to follow standard safety practices for
${tradeName} work, including but not limited to safe handling of tools, electrical
or water supply precautions where applicable, and immediately informing the client
and HandyGo support if a job is outside your competence or unsafe to perform.

4. Quality & Warranty. You agree to redo or correct any work found to be
defective due to your own workmanship within a reasonable period after job
completion, where reasonably possible.

5. Acceptance. By checking the box and submitting your profile for review, you
confirm that you have read, understood, and agree to this Trade-Specific
Agreement for ${tradeName}, in addition to the General Ustaad Agreement.`;

function hashText(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

async function ensureTemplate(params: {
  type: AgreementType;
  categoryId: string | null;
  title: string;
  version: string;
  contentText: string;
}) {
  const existing = await prisma.agreementTemplate.findFirst({
    where: {
      type: params.type,
      categoryId: params.categoryId,
      isActive: true,
    },
  });

  if (existing) {
    console.log(
      `  = ${params.title} already has an active template (id=${existing.id}), skipping.`,
    );
    return existing;
  }

  const created = await prisma.agreementTemplate.create({
    data: {
      type: params.type,
      categoryId: params.categoryId,
      title: params.title,
      version: params.version,
      contentText: params.contentText,
      contentHash: hashText(params.contentText),
      isActive: true,
    },
  });
  console.log(`  + Created "${params.title}" ${params.version} (id=${created.id})`);
  return created;
}

async function main() {
  console.log('Seeding General Ustaad Agreement template...');
  await ensureTemplate({
    type: AgreementType.GENERAL_USTAAD,
    categoryId: null,
    title: 'General Ustaad Agreement',
    version: GENERAL_VERSION,
    contentText: GENERAL_AGREEMENT_TEXT,
  });

  console.log('Seeding Trade-Specific Agreement templates...');
  const categories = await prisma.serviceCategory.findMany({
    where: { isActive: true },
    select: { id: true, name: true },
    orderBy: { name: 'asc' },
  });

  for (const category of categories) {
    await ensureTemplate({
      type: AgreementType.TRADE_SPECIFIC,
      categoryId: category.id,
      title: `${category.name} Trade Agreement`,
      version: TRADE_VERSION,
      contentText: TRADE_AGREEMENT_TEXT(category.name),
    });
  }

  console.log('Agreement template seed complete.');
}

main()
  .catch((e) => {
    console.error('Agreement seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
