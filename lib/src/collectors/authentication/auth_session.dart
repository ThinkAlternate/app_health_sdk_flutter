import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart' as sp;

class SessionManager {
  static const String _sessionKey = 'app_health_sdk_session';

  static Future<void> saveSession(Map<String, dynamic> session) async {
    final prefs = await sp.SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session));
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await sp.SharedPreferences.getInstance();
    final sessionStr = prefs.getString(_sessionKey);
    if (sessionStr == null) return null;
    return jsonDecode(sessionStr);
  }

  static Future<bool> isLoggedIn() async {
    final session = await getSession();
    return session != null && session['token'] != null;
  }

  static Future<void> clearSession() async {
    final prefs = await sp.SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
