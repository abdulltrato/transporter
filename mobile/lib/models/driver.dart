import 'geo_point.dart';

/// Representa um taxista visível no mapa.
class Driver {
  const Driver({
    required this.userId,
    required this.name,
    required this.distanceKm,
    required this.location,
    required this.isOnline,
  });

  final String userId;
  final String name;
  final double distanceKm;
  final GeoPoint location;
  final bool isOnline;

  factory Driver.fromJson(Map<String, dynamic> json) {
    final id = (json['userId'] ?? json['driverId'] ?? '').toString();
    final locationPayload = json['location'] ?? json['coordinates'];
    final location = locationPayload is Map
        ? locationPayload.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final baseName = (json['name'] as String?)?.trim();
    final fallbackId = id.isEmpty ? 'sem-id' : id;

    return Driver(
      userId: id,
      name: (baseName == null || baseName.isEmpty)
          ? 'Taxista ${fallbackId.length > 6 ? fallbackId.substring(0, 6) : fallbackId}'
          : baseName,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      location: GeoPoint.fromJson(location),
      isOnline: json['isOnline'] as bool? ?? true,
    );
  }

  Driver copyWith({
    String? name,
    double? distanceKm,
    GeoPoint? location,
    bool? isOnline,
  }) {
    return Driver(
      userId: userId,
      name: name ?? this.name,
      distanceKm: distanceKm ?? this.distanceKm,
      location: location ?? this.location,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
