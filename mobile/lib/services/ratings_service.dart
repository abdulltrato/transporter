import '../models/driver_rating.dart';
import 'api_client.dart';

class RatingsService {
  RatingsService(this._apiClient);

  final ApiClient _apiClient;

  Future<DriverRating> submitDriverRating({
    required String rideId,
    required int stars,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'rideId': rideId,
      'stars': stars,
    };

    final normalizedComment = comment?.trim() ?? '';
    if (normalizedComment.isNotEmpty) {
      payload['comment'] = normalizedComment;
    }

    final response = await _apiClient.post('/api/ratings/driver', payload);
    final json = _asJsonMap(response);
    if (json == null) {
      throw Exception('Resposta inválida ao avaliar taxista.');
    }

    return DriverRating.fromJson(json);
  }

  Future<List<DriverRating>> listMyGivenRatings() async {
    final response = await _apiClient.get('/api/ratings/me/given');
    if (response is! List<dynamic>) {
      return [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(DriverRating.fromJson)
        .toList();
  }

  Future<DriverRatingSummary> getDriverSummary(String driverId) async {
    final response = await _apiClient.get('/api/ratings/drivers/$driverId/summary');
    final json = _asJsonMap(response);
    if (json == null) {
      throw Exception('Resposta inválida ao carregar resumo de avaliações.');
    }

    return DriverRatingSummary.fromJson(json);
  }
}

Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return null;
}
