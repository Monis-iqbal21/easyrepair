"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingsController = void 0;
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const bookings_service_1 = require("./bookings.service");
const create_booking_dto_1 = require("./dto/create-booking.dto");
const update_booking_dto_1 = require("./dto/update-booking.dto");
const create_review_dto_1 = require("./dto/create-review.dto");
const assign_worker_dto_1 = require("./dto/assign-worker.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const roles_guard_1 = require("../../common/guards/roles.guard");
const role_enum_1 = require("../../common/enums/role.enum");
const ALLOWED_MIME_TYPES = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'video/mp4',
    'video/quicktime',
    'video/3gpp',
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/x-m4a',
    'audio/ogg',
    'audio/wav',
];
const MAX_FILE_SIZE = 50 * 1024 * 1024;
let BookingsController = class BookingsController {
    constructor(bookingsService) {
        this.bookingsService = bookingsService;
    }
    createBooking(user, dto) {
        return this.bookingsService.createBooking(user.id, dto);
    }
    getMyBookings(user) {
        return this.bookingsService.getClientBookings(user.id);
    }
    getBookingById(user, bookingId) {
        return this.bookingsService.getBookingById(user.id, bookingId);
    }
    updateBooking(user, bookingId, dto) {
        return this.bookingsService.updateBooking(user.id, bookingId, dto);
    }
    submitReview(user, bookingId, dto) {
        return this.bookingsService.submitReview(user.id, bookingId, dto);
    }
    cancelBooking(user, bookingId, reason) {
        return this.bookingsService.cancelBooking(user.id, bookingId, reason);
    }
    getNearbyWorkers(user, bookingId, radiusKm) {
        const radiusKmNum = radiusKm !== undefined ? parseFloat(radiusKm) : undefined;
        return this.bookingsService.getNearbyWorkers(user.id, bookingId, radiusKmNum);
    }
    assignWorker(user, bookingId, dto) {
        return this.bookingsService.assignWorker(user.id, bookingId, dto.workerProfileId);
    }
    uploadAttachment(user, bookingId, file) {
        if (!file)
            throw new common_1.BadRequestException('No file provided.');
        return this.bookingsService.uploadAttachment(user.id, bookingId, file);
    }
    async deleteAttachment(user, bookingId, attachmentId) {
        await this.bookingsService.deleteAttachment(user.id, bookingId, attachmentId);
        return { message: 'Attachment deleted.' };
    }
};
exports.BookingsController = BookingsController;
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, create_booking_dto_1.CreateBookingDto]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "createBooking", null);
__decorate([
    (0, common_1.Get)('my'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "getMyBookings", null);
__decorate([
    (0, common_1.Get)(':id'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "getBookingById", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, update_booking_dto_1.UpdateBookingDto]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "updateBooking", null);
__decorate([
    (0, common_1.Post)(':id/review'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, create_review_dto_1.CreateReviewDto]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "submitReview", null);
__decorate([
    (0, common_1.Patch)(':id/cancel'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)('reason')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "cancelBooking", null);
__decorate([
    (0, common_1.Get)(':id/nearby-workers'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Query)('radiusKm')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "getNearbyWorkers", null);
__decorate([
    (0, common_1.Post)(':id/assign'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, assign_worker_dto_1.AssignWorkerDto]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "assignWorker", null);
__decorate([
    (0, common_1.Post)(':id/attachments'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('file', {
        limits: { fileSize: MAX_FILE_SIZE },
        fileFilter: (_req, file, cb) => {
            if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
                cb(null, true);
            }
            else {
                cb(new common_1.BadRequestException(`Unsupported file type: ${file.mimetype}. Allowed: image, video, or audio.`), false);
            }
        },
    })),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.UploadedFile)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, Object]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "uploadAttachment", null);
__decorate([
    (0, common_1.Delete)(':id/attachments/:attachmentId'),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.CLIENT),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Param)('attachmentId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", Promise)
], BookingsController.prototype, "deleteAttachment", null);
exports.BookingsController = BookingsController = __decorate([
    (0, common_1.Controller)('bookings'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    __metadata("design:paramtypes", [bookings_service_1.BookingsService])
], BookingsController);
//# sourceMappingURL=bookings.controller.js.map