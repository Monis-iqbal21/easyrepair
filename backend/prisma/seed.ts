import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const SERVICE_CATEGORIES = [
  {
    name: 'AC Technician',
    description: 'Air conditioning installation, repair & maintenance',
    inspectionFee: 1000,
  },
  {
    name: 'Electrician',
    description: 'Electrical wiring, fuse boards, fixtures & repairs',
    inspectionFee: 500,
  },
  {
    name: 'Plumber',
    description: 'Pipe fitting, leaks, drains & plumbing fixtures',
    inspectionFee: 500,
  },
  {
    name: 'Handyman',
    description: 'General home repairs, assembly & odd jobs',
    inspectionFee: null,
  },
  {
    name: 'Cleaning',
    description: 'Deep cleaning, housekeeping & sanitisation',
    inspectionFee: null,
  },
  {
    name: 'Painter',
    description: 'Interior & exterior painting and finishing',
    inspectionFee: null,
  },
  {
    name: 'Carpenter',
    description: 'Furniture, woodwork & carpentry repairs',
    inspectionFee: 500,
  },
  {
    name: 'Pest Control',
    description: 'Pest extermination & prevention treatments',
    inspectionFee: null,
  },
  {
    name: 'Car Wash',
    description: 'Professional car washing & detailing at home',
    inspectionFee: null,
  },
  {
    name: 'Gardener',
    description: 'Garden maintenance, lawn care & landscaping',
    inspectionFee: null,
  },
];

// Prototype fixed-price catalog per category. Only categories with entries
// here get a "Standard Services" lane; others simply have an empty list.
const STANDARD_SERVICES: Record<
  string,
  { name: string; price: number }[]
> = {
  'AC Technician': [
    { name: 'AC General Service', price: 2100 },
    { name: 'AC Master Service', price: 2600 },
    { name: 'Split AC Installation', price: 3000 },
    { name: 'AC Dismounting', price: 1400 },
  ],
  Electrician: [
    { name: 'Ceiling Fan Installation', price: 800 },
    { name: 'SMD Light Swap', price: 600 },
    { name: 'TV Wall Mount', price: 1500 },
    { name: 'Distribution Box Setup', price: 2500 },
  ],
  Plumber: [
    { name: 'Muslim Shower Set', price: 900 },
    { name: 'Commode Seat Setup', price: 3000 },
    { name: 'Washbasin Installation', price: 1800 },
    { name: 'Drain Clog Cleansing', price: 1500 },
  ],
  Carpenter: [
    { name: 'Door Lock Install', price: 1500 },
    { name: 'Bed Frame Assembly', price: 2000 },
    { name: 'Floating Shelf Install', price: 1200 },
    { name: 'Wooden Door Hanging', price: 3000 },
  ],
};

async function main() {
  console.log('Seeding service categories...');

  const categoryIdByName = new Map<string, string>();

  for (const category of SERVICE_CATEGORIES) {
    const result = await prisma.serviceCategory.upsert({
      where: { name: category.name },
      update: {
        description: category.description,
        isActive: true,
        inspectionFee: category.inspectionFee ?? undefined,
      },
      create: {
        name: category.name,
        description: category.description,
        isActive: true,
        inspectionFee: category.inspectionFee ?? undefined,
      },
    });
    categoryIdByName.set(result.name, result.id);
    console.log(`  ✓ ${result.name} (id=${result.id})`);
  }

  console.log('Seeding standard services...');

  for (const [categoryName, services] of Object.entries(STANDARD_SERVICES)) {
    const categoryId = categoryIdByName.get(categoryName);
    if (!categoryId) {
      console.warn(`  ⚠ Skipping "${categoryName}" — category not found.`);
      continue;
    }

    for (let i = 0; i < services.length; i++) {
      const service = services[i];
      const existing = await prisma.standardService.findFirst({
        where: { categoryId, name: service.name },
      });

      if (existing) {
        await prisma.standardService.update({
          where: { id: existing.id },
          data: { price: service.price, sortOrder: i, isActive: true },
        });
      } else {
        await prisma.standardService.create({
          data: {
            categoryId,
            name: service.name,
            price: service.price,
            sortOrder: i,
            isActive: true,
          },
        });
      }
      console.log(`  ✓ ${categoryName} → ${service.name} (Rs ${service.price})`);
    }
  }

  console.log('Seed complete.');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
