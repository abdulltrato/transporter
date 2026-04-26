import '../models/driver.dart';
import '../models/geo_point.dart';
import 'api_client.dart';

class LocationService {
  LocationService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Driver>> loadNearbyDrivers(GeoPoint point, {double radiusKm = 2}) async {
    final rawItems = await _apiClient.get('/api/location/drivers/nearby', query: {
      'lat': point.lat,
      'lng': point.lng,
      'radiusKm': radiusKm
    });

    return (rawItems as List<dynamic>)
        .map((item) => Driver.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
