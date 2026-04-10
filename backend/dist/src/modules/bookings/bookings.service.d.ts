import { BookingsRepository } from './bookings.repository';
import { CreateBookingDto } from './dto/create-booking.dto';
import { BookingAttachmentDto, BookingResponseDto, NearbyWorkersResponseDto } from './dto/booking-response.dto';
import { UpdateBookingDto } from './dto/update-booking.dto';
import { CreateReviewDto } from './dto/create-review.dto';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ChatService } from '../chat/chat.service';
export declare class BookingsService {
    private readonly bookingsRepository;
    private readonly storageService;
    private readonly notificationsService;
    private readonly chatService;
    private readonly logger;
    constructor(bookingsRepository: BookingsRepository, storageService: StorageService, notificationsService: NotificationsService, chatService: ChatService);
    createBooking(userId: string, dto: CreateBookingDto): Promise<BookingResponseDto>;
    getClientBookings(userId: string): Promise<BookingResponseDto[]>;
    cancelBooking(userId: string, bookingId: string, reason?: string): Promise<BookingResponseDto>;
    getBookingById(userId: string, bookingId: string): Promise<BookingResponseDto>;
    updateBooking(userId: string, bookingId: string, dto: UpdateBookingDto): Promise<BookingResponseDto>;
    submitReview(userId: string, bookingId: string, dto: CreateReviewDto): Promise<BookingResponseDto>;
    uploadAttachment(userId: string, bookingId: string, file: Express.Multer.File): Promise<BookingAttachmentDto>;
    deleteAttachment(userId: string, bookingId: string, attachmentId: string): Promise<void>;
    getNearbyWorkers(userId: string, bookingId: string, radiusKm?: number): Promise<NearbyWorkersResponseDto>;
    assignWorker(userId: string, bookingId: string, workerProfileId: string): Promise<BookingResponseDto>;
    private _resolveAttachmentType;
    private _toDto;
}
