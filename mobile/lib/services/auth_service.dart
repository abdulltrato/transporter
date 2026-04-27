import 'api_client.dart';

/// Serviço de autenticação OTP.
class AuthService {
  AuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<String> requestOtp(String phone) async {
    final response =
        await _apiClient.post('/api/auth/request-otp', {'phone': phone})
            as Map<String, dynamic>;

    return response['devCode']?.toString() ?? '';
  }

  Future<String> verifyOtp({
    required String phone,
    required String code,
    required String role,
    required String fullName,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  }) async {
    final payload = <String, dynamic>{
      'phone': phone,
      'code': code,
      'role': role,
      'fullName': fullName,
    };
    _putIfNotBlank(payload, 'documentId', documentId);
    _putIfNotBlank(payload, 'documentExpiry', documentExpiry);
    _putIfNotBlank(payload, 'neighborhood', neighborhood);
    _putIfNotBlank(payload, 'operatingRegion', operatingRegion);

    final response =
        await _apiClient.post('/api/auth/verify-otp', payload)
            as Map<String, dynamic>;

    return response['accessToken']?.toString() ?? '';
  }

  Future<String> socialLogin({
    required String provider,
    required String providerUserId,
    required String role,
    required String fullName,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  }) async {
    final payload = <String, dynamic>{
      'provider': provider,
      'providerUserId': providerUserId,
      'role': role,
      'fullName': fullName,
    };
    _putIfNotBlank(payload, 'documentId', documentId);
    _putIfNotBlank(payload, 'documentExpiry', documentExpiry);
    _putIfNotBlank(payload, 'neighborhood', neighborhood);
    _putIfNotBlank(payload, 'operatingRegion', operatingRegion);

    final response =
        await _apiClient.post('/api/auth/social', payload)
            as Map<String, dynamic>;

    return response['accessToken']?.toString() ?? '';
  }
}

void _putIfNotBlank(Map<String, dynamic> payload, String key, String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isNotEmpty) {
    payload[key] = normalized;
  }
}
