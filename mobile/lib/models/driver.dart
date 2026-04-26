import 'geo_point.dart';

class Driver {
  const Driver({
    required this.userId,
    required this.name,
    required this.distanceKm,
    required this.location,
    required this.isOnline
  });

  final String userId;
  final String name;
  final double distanceKm;
  final GeoPoint location;
  final bool isOnline;

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Taxista',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      isOnline: json['isOnline'] as bool? ?? true
    );
  }
}
