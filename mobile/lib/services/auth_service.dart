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
  }) async {
    final response =
        await _apiClient.post('/api/auth/verify-otp', {
              'phone': phone,
              'code': code,
              'role': role,
              'fullName': fullName,
            })
            as Map<String, dynamic>;

    return response['accessToken']?.toString() ?? '';
  }
}
