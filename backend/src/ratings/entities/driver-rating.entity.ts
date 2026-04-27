export interface DriverRatingEntity {
  id: string;
  rideId: string;
  driverId: string;
  clientId: string;
  stars: number;
  createdAt: Date;
  updatedAt: Date;
}
