import 'dart:convert';
import 'dart:developer';

import 'package:app_health_sdk/src/collectors/authentication/auth_session.dart';
import 'package:http/http.dart' as http;

class NextJSApiClient {
  final String baseUrl;

  NextJSApiClient(String baseUrl)
    : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Future<Map<String, dynamic>> _makeRequest(String endpoint, Map<String, dynamic> data) async {
    final session = await SessionManager.getSession();
    final headers = {
      'Content-Type': 'application/json',
      if (session?['token'] != null) 'Authorization': 'Bearer ${session?['token']}',
    };

    log("token ${session?['token']}");
    log("url $baseUrl$endpoint");
    log("body ${jsonEncode(data)}");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode >= 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? response.reasonPhrase);
      }

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createProject(String name, String type, double confidence) {
    return _makeRequest('/api/app-health-sdk/projects', {
      'name': name,
      'type': type,
      'confidence': confidence,
    });
  }

  Future<Map<String, dynamic>> uploadAppStoreData(Map<String, dynamic> payload) {
    return _makeRequest('/api/app-health-sdk/appstore/upload', payload);
  }

  Future<Map<String, dynamic>> uploadPlayStoreData(Map<String, dynamic> payload) {
    return _makeRequest('/api/app-health-sdk/playstore/upload', payload);
  }

  Future<Map<String, dynamic>> uploadGitHubData(Map<String, dynamic> payload) {
    return _makeRequest('/api/app-health-sdk/github/upload', payload);
  }

  Future<Map<String, dynamic>> uploadDependencies(Map<String, dynamic> payload) {
    return _makeRequest('/api/app-health-sdk/dependencies/upload', payload);
  }

  Future<Map<String, dynamic>> uploadAnalytics(Map<String, dynamic> payload) {
    return _makeRequest('/api/app-health-sdk/analytics/upload', payload);
  }

  Future<Map<String, dynamic>> fetchConfig(String apiKey) async {
    final session = await SessionManager.getSession();
    return _makeRequest('/api/app-health-sdk/config', {
      'apiKey': apiKey,
      'userId': session?['userId'],
    });
  }
}
