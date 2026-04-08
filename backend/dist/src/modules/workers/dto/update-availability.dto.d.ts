import { AvailabilityStatus } from '@prisma/client';
export declare class UpdateAvailabilityDto {
    status: AvailabilityStatus;
    lat?: number;
    lng?: number;
}
