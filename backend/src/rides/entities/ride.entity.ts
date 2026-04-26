import { RideStatus } from '../../common/enums/ride-status.enum';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';

export interface RideEntity {
  id: string;
  clientId: string;
  driverId?: string;
  pickup: GeoPoint;
  dropoff?: GeoPoint;
  status: RideStatus;
  searchRadiusKm?: number;
  rejectedDriverIds: string[];
  createdAt: Date;
  updatedAt: Date;
}
