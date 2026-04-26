import '../models/geo_point.dart';
import '../models/ride.dart';
import 'api_client.dart';

/// Ações de resposta disponíveis para o taxista.
enum RideResponseAction {
  accept('accept'),
  reject('reject');

  const RideResponseAction(this.value);
  final String value;
}

class RidesService {
  RidesService(this._apiClient);

  final ApiClient _apiClient;

  Future<Ride> requestRide({
    required GeoPoint pickup,
    GeoPoint? dropoff,
  }) async {
    final payload = {
      'pickup': pickup.toJson(),
      if (dropoff != null) 'dropoff': dropoff.toJson(),
    };

    final response = await _apiClient.post('/api/rides/request', payload);
    return Ride.fromJson(_asJsonMap(response));
  }

  Future<Ride> cancelRide(String rideId) async {
    final response = await _apiClient.patch('/api/rides/$rideId/cancel');
    return Ride.fromJson(_asJsonMap(response));
  }

  Future<Ride> startRide(String rideId) async {
    final response = await _apiClient.patch('/api/rides/$rideId/start');
    return Ride.fromJson(_asJsonMap(response));
  }

  Future<Ride> completeRide(String rideId) async {
    final response = await _apiClient.patch('/api/rides/$rideId/complete');
    return Ride.fromJson(_asJsonMap(response));
  }

  Future<Ride> respondToRide({
    required String rideId,
    required RideResponseAction action,
  }) async {
    final response = await _apiClient.patch(
      '/api/rides/$rideId/respond',
      body: {'action': action.value},
    );
    return Ride.fromJson(_asJsonMap(response));
  }

  Future<List<Ride>> listMyRides() async {
    final response = await _apiClient.get('/api/rides/me');
    if (response is! List<dynamic>) {
      return [];
    }

    return response
        .map(_asJsonMap)
        .where((item) => item.isNotEmpty)
        .map(Ride.fromJson)
        .toList();
  }
}

/// Converte payloads dinâmicos em mapas seguros para os modelos.
Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return <String, dynamic>{};
}
