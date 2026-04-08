import { WorkersService } from './workers.service';
import { UpdateAvailabilityDto } from './dto/update-availability.dto';
import { UpdateSkillsDto } from './dto/update-skills.dto';
export declare class WorkersController {
    private readonly workersService;
    constructor(workersService: WorkersService);
    getProfile(user: {
        id: string;
    }): Promise<{
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
    updateAvailability(user: {
        id: string;
    }, dto: UpdateAvailabilityDto): Promise<{
        availabilityStatus: import(".prisma/client").$Enums.AvailabilityStatus;
        currentLat: number | null;
        currentLng: number | null;
        locationUpdatedAt: Date | null;
    }>;
    updateSkills(user: {
        id: string;
    }, dto: UpdateSkillsDto): Promise<{
        id: string;
        yearsExperience: number;
        category: {
            id: string;
            name: string;
            iconUrl: string | null;
        };
    }[]>;
    getWorkerJobs(user: {
        id: string;
    }, filter?: 'active' | 'completed' | 'cancelled'): Promise<import("./dto/worker-job-response.dto").WorkerJobResponseDto[]>;
    getWorkerJobById(user: {
        id: string;
    }, id: string): Promise<import("./dto/worker-job-response.dto").WorkerJobResponseDto>;
    updateJobStatus(user: {
        id: string;
    }, id: string, status: string): Promise<import("./dto/worker-job-response.dto").WorkerJobResponseDto>;
    cancelJob(user: {
        id: string;
    }, id: string, reason?: string): Promise<import("./dto/worker-job-response.dto").WorkerJobResponseDto>;
    completeJob(user: {
        id: string;
    }, id: string): Promise<import("./dto/worker-job-response.dto").WorkerJobResponseDto>;
    getWorkerReviews(user: {
        id: string;
    }, limit?: string): Promise<import("./dto/worker-review-response.dto").WorkerReviewResponseDto[]>;
    getWorkerReviewSummary(user: {
        id: string;
    }): Promise<import("./dto/worker-review-response.dto").WorkerReviewSummaryDto>;
}
