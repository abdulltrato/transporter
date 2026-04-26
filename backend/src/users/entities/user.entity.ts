import { UserRole } from '../../common/enums/user-role.enum';

export interface UserEntity {
  id: string;
  fullName: string;
  phone: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
}
