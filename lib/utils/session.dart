// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'madrasa_session';

  static Future<void> saveSession(
    String role,
    int userId, {
    List<String>? permissions,
    String? token,
    String? name,
    List<String>? assignedClasses,
  }) async {
    final data = {
      'role': role,
      'userId': userId,
      'permissions': permissions ?? [],
      'token': token,
      'name': name,
      'assignedClasses': assignedClasses ?? [],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _storage.write(key: _sessionKey, value: jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final str = await _storage.read(key: _sessionKey);
      if (str == null || str.isEmpty) return null;
      final data = jsonDecode(str);

      return data;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {
      return;
    }
  }
}
