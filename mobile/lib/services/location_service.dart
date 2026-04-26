import '../models/driver.dart';
import '../models/geo_point.dart';
import 'api_client.dart';

/// Serviço responsável por operações de localização no backend.
class LocationService {
  LocationService(this._apiClient);

  final ApiClient _apiClient;

  Future<GeoPoint?> loadMyLocation() async {
    final response = await _apiClient.get('/api/location/me');
    final payload = _asJsonMap(response);
    if (payload == null) {
      return null;
    }

    final coordinates = _asJsonMap(payload['coordinates']);
    if (coordinates == null) {
      return null;
    }

    return GeoPoint.fromJson(coordinates);
  }

  Future<GeoPoint> updateMyLocation(GeoPoint point) async {
    final response = await _apiClient.put(
      '/api/location/me',
      body: point.toJson(),
    );
    final payload = _asJsonMap(response);
    if (payload == null) {
      return point;
    }

    final coordinates = _asJsonMap(payload['coordinates']);
    if (coordinates == null) {
      return point;
    }

    return GeoPoint.fromJson(coordinates);
  }

  Future<List<Driver>> loadNearbyDrivers(
    GeoPoint point, {
    double radiusKm = 2,
  }) async {
    final response = await _apiClient.get(
      '/api/location/drivers/nearby',
      query: {'lat': point.lat, 'lng': point.lng, 'radiusKm': radiusKm},
    );

    if (response is! List<dynamic>) {
      return [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map((item) => Driver.fromJson(item))
        .toList();
  }
}

/// Normaliza cargas JSON dinâmicas para `Map<String, dynamic>`.
Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return null;
}
