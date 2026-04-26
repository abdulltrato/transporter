import { DriverStatus } from '../../common/enums/driver-status.enum';

export interface DriverProfileEntity {
  userId: string;
  documentId?: string;
  documentExpiry?: string;
  neighborhood?: string;
  operatingRegion?: string;
  status: DriverStatus;
  createdAt: Date;
  updatedAt: Date;
}
