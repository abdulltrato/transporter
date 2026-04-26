import { UserRole } from '../enums/user-role.enum';

export interface RequestUser {
  id: string;
  phone: string;
  role: UserRole;
}
