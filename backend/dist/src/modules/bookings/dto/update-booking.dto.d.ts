import { BookingUrgency, TimeSlot } from '@prisma/client';
export declare class UpdateBookingDto {
    serviceCategory?: string;
    title?: string;
    description?: string;
    urgency?: BookingUrgency;
    timeSlot?: TimeSlot;
    scheduledAt?: string;
    addressLine?: string;
    city?: string;
    latitude?: number;
    longitude?: number;
}
