import { UserRole } from '../../common/enums/user-role.enum';

export interface JwtPayload {
  sub: string;
  phone: string;
  role: UserRole;
}
