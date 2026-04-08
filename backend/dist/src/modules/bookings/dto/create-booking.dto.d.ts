import { BookingUrgency, TimeSlot } from '@prisma/client';
export declare class CreateBookingDto {
    serviceCategory: string;
    urgency: BookingUrgency;
    timeSlot?: TimeSlot;
    scheduledAt?: string;
    title?: string;
    description?: string;
    addressLine: string;
    city?: string;
    latitude: number;
    longitude: number;
}
