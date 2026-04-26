class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng
    };
  }
}
