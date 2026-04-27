import '../models/driver_profile.dart';
import 'api_client.dart';

class DriversService {
  DriversService(this._apiClient);

  final ApiClient _apiClient;

  Future<DriverProfile> loadMyProfile() async {
    final response = await _apiClient.get('/api/drivers/me/profile');
    final payload = _asJsonMap(response);
    if (payload == null) {
      throw Exception('Resposta inválida ao carregar perfil do taxista.');
    }

    return DriverProfile.fromJson(payload);
  }

  Future<DriverProfile> updateMyProfile({
    required String documentId,
    required String documentExpiry,
    required String neighborhood,
    required String operatingRegion,
  }) async {
    final response = await _apiClient.patch(
      '/api/drivers/me/profile',
      body: {
        'documentId': documentId,
        'documentExpiry': documentExpiry,
        'neighborhood': neighborhood,
        'operatingRegion': operatingRegion,
      },
    );
    final payload = _asJsonMap(response);
    if (payload == null) {
      throw Exception('Resposta inválida ao atualizar perfil do taxista.');
    }

    return DriverProfile.fromJson(payload);
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
