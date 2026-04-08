"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
const SERVICE_CATEGORIES = [
    {
        name: 'AC Technician',
        description: 'Air conditioning installation, repair & maintenance',
    },
    {
        name: 'Electrician',
        description: 'Electrical wiring, fuse boards, fixtures & repairs',
    },
    {
        name: 'Plumber',
        description: 'Pipe fitting, leaks, drains & plumbing fixtures',
    },
    {
        name: 'Handyman',
        description: 'General home repairs, assembly & odd jobs',
    },
];
async function main() {
    console.log('Seeding service categories...');
    for (const category of SERVICE_CATEGORIES) {
        const result = await prisma.serviceCategory.upsert({
            where: { name: category.name },
            update: { description: category.description, isActive: true },
            create: {
                name: category.name,
                description: category.description,
                isActive: true,
            },
        });
        console.log(`  ✓ ${result.name} (id=${result.id})`);
    }
    console.log('Seed complete.');
}
main()
    .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
})
    .finally(() => prisma.$disconnect());
//# sourceMappingURL=seed.js.map