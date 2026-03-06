import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class AppStoreCollector {
  final String keyId;
  final String issuerId;
  final String privateKey;
  final String bundleId;
  static const String baseURL = 'https://api.appstoreconnect.apple.com/v1';

  String? _token;
  DateTime? _tokenExpiry;

  AppStoreCollector({
    required this.keyId,
    required this.issuerId,
    required String privateKeyPath,
    required this.bundleId,
  }) : privateKey = File(privateKeyPath).readAsStringSync();

  String _generateJWT() {
    final now = DateTime.now();
    final expiry = now.add(Duration(minutes: 20));

    final claims = JsonWebTokenClaims.fromJson({
      'iss': issuerId,
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'aud': 'appstoreconnect-v1',
      'iat': now.millisecondsSinceEpoch ~/ 1000,
    });

    final builder = JsonWebSignatureBuilder()
      ..jsonContent = claims.toJson()
      ..addRecipient(JsonWebKey.fromPem(privateKey), algorithm: 'ES256')
      ..setProtectedHeader('kid', keyId)
      ..setProtectedHeader('typ', 'JWT');

    return builder.build().toCompactSerialization();
  }

  String _getAuthToken() {
    final now = DateTime.now();
    if (_token == null || _tokenExpiry == null || now.isAfter(_tokenExpiry!)) {
      _token = _generateJWT();
      _tokenExpiry = now.add(Duration(minutes: 20));
    }
    return _token!;
  }

  Future<Map<String, dynamic>> _makeRequest(
    String endpoint, {
    Map<String, String>? params,
    Map<String, dynamic>? data,
    String method = 'GET',
  }) async {
    final uri = Uri.parse('$baseURL$endpoint').replace(queryParameters: params);

    final headers = {
      'Authorization': 'Bearer ${_getAuthToken()}',
      'Content-Type': 'application/json',
    };

    http.Response response;
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: jsonEncode(data));
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: jsonEncode(data));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        response = await http.get(uri, headers: headers);
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getApp() async {
    final apps = await _makeRequest('/apps', params: {'filter[bundleId]': bundleId});

    if (apps['data'] == null || (apps['data'] as List).isEmpty) {
      throw Exception('App with bundle ID $bundleId not found');
    }

    return apps['data'][0];
  }

  Future<Map<String, dynamic>> getPerfMetrics(DateTime startDate, DateTime endDate) async {
    final app = await getApp();
    final appId = app['id'];

    final apps = await _makeRequest('/apps/$appId/perfPowerMetrics');

    if (apps['data'] == null || (apps['data'] as List).isEmpty) {
      throw Exception('Performance metrics not found');
    }

    return apps['data'][0];
  }

  Future<Map<String, dynamic>> getVitals(DateTime startDate, DateTime endDate) async {
    final app = await getApp();
    final appId = app['id'];

    final versions = await _makeRequest('/apps/$appId/appStoreVersions');
    final allData = <String, dynamic>{'app': app};

    if (versions['data'] != null && (versions['data'] as List).isNotEmpty) {
      final versionList = versions['data'] as List;
      for (final version in versionList.take(3)) {
        try {
          final diagnostics = await _makeRequest(
            '/appStoreVersions/${version['id']}/diagnosticSignatures',
          );
          allData['diagnostics_${version['attributes']['versionString']}'] =
              diagnostics['data'] ?? [];
        } catch (e) {
          // Skip if diagnostics not available
        }
      }
    }

    try {
      final betaFeedback = await _makeRequest(
        '/apps/$appId/betaFeedbacks',
        params: {'sort': '-createdDate', 'limit': '100'},
      );
      allData['betaFeedback'] = betaFeedback['data'] ?? [];
    } catch (e) {
      allData['betaFeedback'] = [];
    }

    return allData;
  }

  Future<Map<String, dynamic>> getPricing() async {
    final app = await getApp();
    final appId = app['id'];

    final inAppPurchases = await _makeRequest('/apps/$appId/inAppPurchases');
    final subscriptions = await _makeRequest(
      '/apps/$appId/subscriptionGroups',
      params: {'include': 'subscriptions'},
    );

    return {
      'inAppPurchases': inAppPurchases['data'] ?? [],
      'subscriptions': subscriptions['data'] ?? [],
    };
  }

  Future<Map<String, dynamic>> getAnalytics(DateTime startDate, DateTime endDate) async {
    final app = await getApp();
    final appId = app['id'];

    final analytics = await _makeRequest(
      '/apps/$appId/analyticsReportRequests',
      params: {
        'include': 'reports',
        'fields[analyticsReportRequests]': 'accessType,reports',
        'fields[analyticsReports]': 'category',
      },
    );

    return {'analytics': analytics['data'] ?? []};
  }

  Future<Map<String, dynamic>> getReportInstance() async {
    // final reportId = 'r154-81b125da-363f-4911-9570-5740292230e9';

    // final reportDetails = await _makeRequest(
    //   '/analyticsReports/$reportId',
    //   params: {'fields[analyticsReports]': 'instances,category,name'},
    // );

    // final reportInstances = await _makeRequest(
    //   '/analyticsReports/$reportId/instances',
    //   params: {'filter[processingDate]': '2025-05-01', 'filter[granularity]': 'DAILY'},
    // );

    final analyticsData = await _makeRequest(
      '/analyticsReportInstances/81b125da-363f-4911-9570-5740292230e9',
    );

    return {'analyticsData': analyticsData['data'] ?? []};
  }

  Future<Map<String, dynamic>> getAppVersions() async {
    final app = await getApp();
    final appId = app['id'];

    final versions = await _makeRequest('/apps/$appId/appStoreVersions');
    return {'versions': versions['data'] ?? []};
  }

  Future<Map<String, dynamic>> getReviews() async {
    final app = await getApp();
    final appId = app['id'];

    final reviews = await _makeRequest(
      '/apps/$appId/customerReviews',
      params: {'sort': '-createdDate', 'limit': '200'},
    );

    return {'reviews': reviews['data'] ?? []};
  }
}
