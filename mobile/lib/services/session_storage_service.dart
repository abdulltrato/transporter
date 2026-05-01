import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  const StoredSession({
    required this.userId,
    required this.role,
  });

  final String userId;
  final String role;
}

class SessionStorageService {
  static const _userIdKey = 'transporter.user_id';
  static const _roleKey = 'transporter.role';

  Future<void> saveSession({
    required String userId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_roleKey, role);
  }

  Future<StoredSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString(_userIdKey) ?? '').trim();
    final role = (prefs.getString(_roleKey) ?? '').trim();

    if (userId.isEmpty || role.isEmpty) {
      return null;
    }

    return StoredSession(userId: userId, role: role);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }
}
