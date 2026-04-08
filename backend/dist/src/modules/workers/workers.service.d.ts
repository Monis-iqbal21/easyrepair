import { WorkersRepository } from './workers.repository';
import { NotificationsService } from '../notifications/notifications.service';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateSkillsDto } from './dto/update-skills.dto';
import { WorkerJobResponseDto } from './dto/worker-job-response.dto';
import { WorkerReviewResponseDto, WorkerReviewSummaryDto } from './dto/worker-review-response.dto';
export declare class WorkersService {
    private readonly workersRepository;
    private readonly notificationsService;
    private readonly logger;
    constructor(workersRepository: WorkersRepository, notificationsService: NotificationsService);
    getProfile(userId: string): Promise<{
        id: string;
        userId: string;
        firstName: string;
        lastName: string;
        avatarUrl: string | null;
        bio: string | null;
        status: import(".prisma/client").$Enums.WorkerStatus;
        verificationStatus: import(".prisma/client").$Enums.VerificationStatus;
        availabilityStatus: import(".prisma/client").$Enums.AvailabilityStatus;
        currentlyWorking: boolean;
        currentLat: number | null;
        currentLng: number | null;
        locationUpdatedAt: Date | null;
        rating: number;
        totalRatings: number;
        skills: {
            id: string;
            yearsExperience: number;
            category: {
                id: string;
                name: string;
                iconUrl: string | null;
            };
        }[];
        stats: {
            completedJobs: number;
            activeJobs: number;
        };
        ongoingJob: {
            id: string;
            title: string | null;
            categoryName: string;
            clientArea: string;
            addressLine: string;
            status: import(".prisma/client").$Enums.BookingStatus;
        } | null;
    }>;
    updateAvailability(userId: string, dto: UpdateAvailabilityDto): Promise<{
        availabilityStatus: import(".prisma/client").$Enums.AvailabilityStatus;
        currentLat: number | null;
        currentLng: number | null;
        locationUpdatedAt: Date | null;
    }>;
    updateSkills(userId: string, dto: UpdateSkillsDto): Promise<{
        id: string;
        yearsExperience: number;
        category: {
            id: string;
            name: string;
            iconUrl: string | null;
        };
    }[]>;
    getWorkerJobs(userId: string, statusFilter?: 'active' | 'completed' | 'cancelled'): Promise<WorkerJobResponseDto[]>;
    getWorkerJobById(userId: string, bookingId: string): Promise<WorkerJobResponseDto>;
    completeJob(userId: string, bookingId: string): Promise<WorkerJobResponseDto>;
    updateJobStatus(userId: string, bookingId: string, status: 'EN_ROUTE' | 'IN_PROGRESS'): Promise<WorkerJobResponseDto>;
    cancelJob(userId: string, bookingId: string, reason?: string): Promise<WorkerJobResponseDto>;
    private _toJobDto;
    getWorkerReviews(userId: string, limit?: number): Promise<WorkerReviewResponseDto[]>;
    getWorkerReviewSummary(userId: string): Promise<WorkerReviewSummaryDto>;
}
