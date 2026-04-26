import { GeoPoint } from '../interfaces/geo-point.interface';

const EARTH_RADIUS_KM = 6371;

function toRadians(value: number): number {
  return (value * Math.PI) / 180;
}

export function calculateDistanceInKm(origin: GeoPoint, destination: GeoPoint): number {
  const dLat = toRadians(destination.lat - origin.lat);
  const dLng = toRadians(destination.lng - origin.lng);

  const lat1 = toRadians(origin.lat);
  const lat2 = toRadians(destination.lat);

  const haversine =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;

  const arc = 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
  return EARTH_RADIUS_KM * arc;
}
