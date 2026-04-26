import 'geo_point.dart';

class Ride {
  const Ride({
    required this.id,
    required this.status,
    required this.pickup,
    this.dropoff,
    this.driverId,
    this.searchRadiusKm,
    this.rejectedDriverIds,
    this.updatedAt
  });

  final String id;
  final String status;
  final GeoPoint pickup;
  final GeoPoint? dropoff;
  final String? driverId;
  final double? searchRadiusKm;
  final List<String>? rejectedDriverIds;
  final DateTime? updatedAt;

  factory Ride.fromJson(Map<String, dynamic> json) {
    final pickupPayload = json['pickup'] is Map
        ? (json['pickup'] as Map).map(
            (key, value) => MapEntry(key.toString(), value)
          )
        : const <String, dynamic>{};
    final dropoffPayload = json['dropoff'] is Map
        ? (json['dropoff'] as Map).map(
            (key, value) => MapEntry(key.toString(), value)
          )
        : null;

    return Ride(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      pickup: GeoPoint.fromJson(pickupPayload),
      dropoff: dropoffPayload == null ? null : GeoPoint.fromJson(dropoffPayload),
      driverId: json['driverId']?.toString(),
      searchRadiusKm: (json['searchRadiusKm'] as num?)?.toDouble(),
      rejectedDriverIds: (json['rejectedDriverIds'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')
    );
  }

  Ride copyWith({
    String? status,
    GeoPoint? pickup,
    GeoPoint? dropoff,
    String? driverId,
    double? searchRadiusKm,
    List<String>? rejectedDriverIds,
    DateTime? updatedAt
  }) {
    return Ride(
      id: id,
      status: status ?? this.status,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      driverId: driverId ?? this.driverId,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      rejectedDriverIds: rejectedDriverIds ?? this.rejectedDriverIds,
      updatedAt: updatedAt ?? this.updatedAt
    );
  }
}
