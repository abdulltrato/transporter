import 'api_client.dart';

class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
}

class RegistrationResult {
  const RegistrationResult({
    required this.user,
    required this.userId,
    required this.role,
  });

  final RegisteredUser user;
  final String userId;
  final String role;
}

class AuthService {
  AuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<RegistrationResult> register({
    required String fullName,
    required String phone,
    required String role,
    String? documentId,
    String? documentExpiry,
    String? neighborhood,
    String? operatingRegion,
  }) async {
    final payload = <String, dynamic>{
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'role': role.trim().toLowerCase(),
    };
    _putIfNotBlank(payload, 'documentId', documentId);
    _putIfNotBlank(payload, 'documentExpiry', documentExpiry);
    _putIfNotBlank(payload, 'neighborhood', neighborhood);
    _putIfNotBlank(payload, 'operatingRegion', operatingRegion);

    final response = await _apiClient.post('/api/auth/register', payload);
    final root = _asJsonMap(response);
    final userJson = _asJsonMap(root['user']);
    final sessionJson = _asJsonMap(root['session']);

    final user = RegisteredUser(
      id: userJson['id']?.toString() ?? '',
      fullName: userJson['fullName']?.toString() ?? '',
      phone: userJson['phone']?.toString() ?? '',
      role: userJson['role']?.toString() ?? role,
    );

    final userId = sessionJson['userId']?.toString() ?? user.id;
    final resolvedRole = sessionJson['role']?.toString() ?? user.role;

    if (userId.trim().isEmpty || resolvedRole.trim().isEmpty) {
      throw Exception('Resposta inválida ao registar utilizador.');
    }

    return RegistrationResult(user: user, userId: userId, role: resolvedRole);
  }
}

void _putIfNotBlank(Map<String, dynamic> payload, String key, String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isNotEmpty) {
    payload[key] = normalized;
  }
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return <String, dynamic>{};
}
