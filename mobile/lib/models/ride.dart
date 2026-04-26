import 'geo_point.dart';

class Ride {
  const Ride({
    required this.id,
    required this.status,
    required this.pickup,
    this.dropoff,
    this.driverId
  });

  final String id;
  final String status;
  final GeoPoint pickup;
  final GeoPoint? dropoff;
  final String? driverId;

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as String,
      status: json['status'] as String,
      pickup: GeoPoint.fromJson(json['pickup'] as Map<String, dynamic>),
      dropoff: json['dropoff'] == null
          ? null
          : GeoPoint.fromJson(json['dropoff'] as Map<String, dynamic>),
      driverId: json['driverId'] as String?
    );
  }
}
