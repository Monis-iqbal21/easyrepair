declare const _default: () => {
    port: number;
    database: {
        url: string | undefined;
    };
    redis: {
        url: string | undefined;
    };
    jwt: {
        secret: string | undefined;
        accessExpires: string;
        refreshExpires: string;
    };
    firebase: {
        projectId: string | undefined;
        privateKey: string | undefined;
        clientEmail: string | undefined;
    };
    sms: {
        apiKey: string | undefined;
    };
    storage: {
        provider: string;
        bucket: string | undefined;
        region: string | undefined;
        accessKey: string | undefined;
        secretKey: string | undefined;
    };
    platform: {
        feePercent: number;
    };
    usePostgis: boolean;
};
export default _default;
