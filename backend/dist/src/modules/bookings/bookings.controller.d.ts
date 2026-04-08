import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { UpdateBookingDto } from './dto/update-booking.dto';
import { CreateReviewDto } from './dto/create-review.dto';
import { AssignWorkerDto } from './dto/assign-worker.dto';
export declare class BookingsController {
    private readonly bookingsService;
    constructor(bookingsService: BookingsService);
    createBooking(user: {
        id: string;
    }, dto: CreateBookingDto): Promise<import("./dto/booking-response.dto").BookingResponseDto>;
    getMyBookings(user: {
        id: string;
    }): Promise<import("./dto/booking-response.dto").BookingResponseDto[]>;
    getBookingById(user: {
        id: string;
    }, bookingId: string): Promise<import("./dto/booking-response.dto").BookingResponseDto>;
    updateBooking(user: {
        id: string;
    }, bookingId: string, dto: UpdateBookingDto): Promise<import("./dto/booking-response.dto").BookingResponseDto>;
    submitReview(user: {
        id: string;
    }, bookingId: string, dto: CreateReviewDto): Promise<import("./dto/booking-response.dto").BookingResponseDto>;
    cancelBooking(user: {
        id: string;
    }, bookingId: string, reason?: string): Promise<import("./dto/booking-response.dto").BookingResponseDto>;
    getNearbyWorkers(user: {
        id: string;
    }, bookingId: string, radiusKm?: string): Promise<import("./dto/booking-response.dto").NearbyWorkersResponseDto>;
    assignWorker(user: {
        id: string;
    }, bookingId: string, dto: AssignWorkerDto): Promise<import("./dto/booking-response.dto").BookingResponseDto>;
    uploadAttachment(user: {
        id: string;
    }, bookingId: string, file: Express.Multer.File): Promise<import("./dto/booking-response.dto").BookingAttachmentDto>;
    deleteAttachment(user: {
        id: string;
    }, bookingId: string, attachmentId: string): Promise<{
        message: string;
    }>;
}
