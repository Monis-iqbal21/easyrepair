import { CallHandler, ExecutionContext, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import { ApiSuccessResponse } from '../interfaces/api-response.interface';
export declare class TransformInterceptor<T> implements NestInterceptor<T, ApiSuccessResponse<T>> {
    intercept(_context: ExecutionContext, next: CallHandler): Observable<ApiSuccessResponse<T>>;
}
