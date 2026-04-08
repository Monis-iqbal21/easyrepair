import { Role } from '../../../common/enums/role.enum';
export interface TokenPayload {
    sub: string;
    phone: string;
    role: Role;
}
