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
exports.WorkersController = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const workers_service_1 = require("./workers.service");
const update_availability_dto_1 = require("./dto/update-availability.dto");
const update_skills_dto_1 = require("./dto/update-skills.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const role_enum_1 = require("../../common/enums/role.enum");
let WorkersController = class WorkersController {
    constructor(workersService) {
        this.workersService = workersService;
    }
    getProfile(user) {
        return this.workersService.getProfile(user.id);
    }
    updateAvailability(user, dto) {
        return this.workersService.updateAvailability(user.id, dto);
    }
    updateSkills(user, dto) {
        return this.workersService.updateSkills(user.id, dto);
    }
    getWorkerJobs(user, filter) {
        return this.workersService.getWorkerJobs(user.id, filter);
    }
    getWorkerJobById(user, id) {
        return this.workersService.getWorkerJobById(user.id, id);
    }
    updateJobStatus(user, id, status) {
        if (status !== client_1.BookingStatus.EN_ROUTE && status !== client_1.BookingStatus.IN_PROGRESS) {
            throw new common_1.BadRequestException("status must be 'EN_ROUTE' or 'IN_PROGRESS'");
        }
        return this.workersService.updateJobStatus(user.id, id, status);
    }
    cancelJob(user, id, reason) {
        return this.workersService.cancelJob(user.id, id, reason);
    }
    completeJob(user, id) {
        return this.workersService.completeJob(user.id, id);
    }
    getWorkerReviews(user, limit) {
        const parsedLimit = limit !== undefined ? parseInt(limit, 10) : undefined;
        return this.workersService.getWorkerReviews(user.id, Number.isFinite(parsedLimit) ? parsedLimit : undefined);
    }
    getWorkerReviewSummary(user) {
        return this.workersService.getWorkerReviewSummary(user.id);
    }
};
exports.WorkersController = WorkersController;
__decorate([
    (0, common_1.Get)('profile'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "getProfile", null);
__decorate([
    (0, common_1.Patch)('availability'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_availability_dto_1.UpdateAvailabilityDto]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "updateAvailability", null);
__decorate([
    (0, common_1.Put)('skills'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_skills_dto_1.UpdateSkillsDto]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "updateSkills", null);
__decorate([
    (0, common_1.Get)('jobs'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('filter')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "getWorkerJobs", null);
__decorate([
    (0, common_1.Get)('jobs/:id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "getWorkerJobById", null);
__decorate([
    (0, common_1.Patch)('jobs/:id/status'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "updateJobStatus", null);
__decorate([
    (0, common_1.Patch)('jobs/:id/cancel'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)('reason')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "cancelJob", null);
__decorate([
    (0, common_1.Patch)('jobs/:id/complete'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "completeJob", null);
__decorate([
    (0, common_1.Get)('reviews'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "getWorkerReviews", null);
__decorate([
    (0, common_1.Get)('reviews/summary'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], WorkersController.prototype, "getWorkerReviewSummary", null);
exports.WorkersController = WorkersController = __decorate([
    (0, common_1.Controller)('workers'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)(role_enum_1.Role.WORKER),
    __metadata("design:paramtypes", [workers_service_1.WorkersService])
], WorkersController);
//# sourceMappingURL=workers.controller.js.map