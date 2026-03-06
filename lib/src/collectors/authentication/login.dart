import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  Future<String> _askQuestion(String query, {bool hidden = false}) async {
    stdout.write(query);

    if (hidden) {
      stdin.echoMode = false;
    }

    final answer = stdin.readLineSync() ?? '';

    if (hidden) {
      stdin.echoMode = true;
      stdout.writeln(); // New line after hidden input
    }

    return answer;
  }

  Future<void> login(String apiUrl) async {
    try {
      final email = await _askQuestion('Email: ');
      final password = await _askQuestion('Password: ', hidden: true);

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['userId'];
        final token = data['token'];

        await _saveSession(userId: userId, token: token);
        debugPrint('✅ Logged in as $userId');
      } else {
        debugPrint('❌ Login failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Login failed: $e');
    }
  }

  Future<void> _saveSession({required String userId, required String token}) async {
    final file = File('.session.json');
    await file.writeAsString(jsonEncode({'userId': userId, 'token': token}));
  }
}
