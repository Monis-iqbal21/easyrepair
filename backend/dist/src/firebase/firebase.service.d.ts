import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
export declare class FirebaseService implements OnModuleInit {
    private readonly config;
    private readonly logger;
    private messaging;
    constructor(config: ConfigService);
    onModuleInit(): void;
    sendPush(fcmToken: string, title: string, body: string, data?: Record<string, string>): Promise<void>;
}
