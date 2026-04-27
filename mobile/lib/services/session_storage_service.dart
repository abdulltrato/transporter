import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.role,
  });

  final String accessToken;
  final String role;
}

class SessionStorageService {
  static const _accessTokenKey = 'transporter.access_token';
  static const _roleKey = 'transporter.role';

  Future<void> saveSession({
    required String accessToken,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_roleKey, role);
  }

  Future<StoredSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = (prefs.getString(_accessTokenKey) ?? '').trim();
    final role = (prefs.getString(_roleKey) ?? '').trim();

    if (accessToken.isEmpty || role.isEmpty) {
      return null;
    }

    return StoredSession(accessToken: accessToken, role: role);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_roleKey);
  }
}
