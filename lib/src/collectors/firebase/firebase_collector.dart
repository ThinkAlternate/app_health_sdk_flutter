import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';

class FirebaseCollector {
  final Map<String, dynamic> serviceAccountKey;
  final String projectId;
  AutoRefreshingAuthClient? _authClient;

  static const String _analyticsUrl = 'https://analyticsdata.googleapis.com/v1beta';

  FirebaseCollector({required this.serviceAccountKey, required this.projectId});

  Future<void> initialize() async {
    final credentials = ServiceAccountCredentials.fromJson(serviceAccountKey);
    final scopes = [
      'https://www.googleapis.com/auth/analytics.readonly',
      'https://www.googleapis.com/auth/firebase',
      'https://www.googleapis.com/auth/cloud-platform',
    ];
    _authClient = await clientViaServiceAccount(credentials, scopes);
  }

  Future<Map<String, dynamic>> _runReport(String propertyId, Map<String, dynamic> body) async {
    final res = await _authClient!.post(
      Uri.parse('$_analyticsUrl/properties/$propertyId:runReport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getUsersPerCountry(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [
        {'name': 'country'},
      ],
      'metrics': [
        {'name': 'newUsers'},
      ],
      'dateRanges': [
        {'startDate': '2023-01-01', 'endDate': 'today'},
      ],
    });
  }

  Future<Map<String, dynamic>> getTotalInstalls(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'eventCount'},
      ],
      'dateRanges': [
        {'startDate': '2023-01-01', 'endDate': 'today'},
      ],
      'dimensionFilter': {
        'filter': {
          'fieldName': 'eventName',
          'stringFilter': {'value': 'first_open', 'matchType': 'EXACT'},
        },
      },
    });
  }

  Future<Map<String, dynamic>> getLiveUsers(String propertyId) async {
    final res = await _authClient!.post(
      Uri.parse('$_analyticsUrl/properties/$propertyId:runRealtimeReport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'dimensions': [
          {'name': 'country'},
        ],
        'metrics': [
          {'name': 'activeUsers'},
        ],
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getDailyActiveUsers(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'active1DayUsers'},
      ],
      'dateRanges': [
        {'startDate': 'yesterday', 'endDate': 'today'},
      ],
    });
  }

  Future<Map<String, dynamic>> getWeeklyActiveUsers(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'active7DayUsers'},
      ],
      'dateRanges': [
        {'startDate': '7daysAgo', 'endDate': 'today'},
      ],
    });
  }

  Future<Map<String, dynamic>> getMonthlyActiveUsers(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'active28DayUsers'},
      ],
      'dateRanges': [
        {'startDate': '28daysAgo', 'endDate': 'today'},
      ],
    });
  }

  Future<Map<String, dynamic>> getAllActiveUsers(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'active1DayUsers'},
        {'name': 'active7DayUsers'},
        {'name': 'active28DayUsers'},
      ],
      'dateRanges': [
        {'startDate': '28daysAgo', 'endDate': 'yesterday'},
      ],
    });
  }

  Future<Map<String, dynamic>> getDailyInstalls(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'eventCount'},
      ],
      'dateRanges': [
        {'startDate': '2025-09-06', 'endDate': 'today'},
      ],
      'dimensionFilter': {
        'filter': {
          'fieldName': 'eventName',
          'stringFilter': {'value': 'first_open', 'matchType': 'EXACT'},
        },
      },
    });
  }

  Future<Map<String, dynamic>> getWeeklyInstalls(String propertyId) async {
    return _runReport(propertyId, {
      'dimensions': [],
      'metrics': [
        {'name': 'eventCount'},
      ],
      'dateRanges': [
        {'startDate': '2025-09-01', 'endDate': 'yesterday'},
      ],
      'dimensionFilter': {
        'filter': {
          'fieldName': 'eventName',
          'stringFilter': {'value': 'first_open', 'matchType': 'EXACT'},
        },
      },
    });
  }

  Future<Map<String, dynamic>> getMonthlyInstalls(String propertyId) async {
    return _runReport(propertyId, {
      'metrics': [
        {'name': 'eventCount'},
      ],
      'dateRanges': [
        {'startDate': '28daysAgo', 'endDate': 'today'},
      ],
      'dimensionFilter': {
        'filter': {
          'fieldName': 'eventName',
          'stringFilter': {'value': 'first_open', 'matchType': 'EXACT'},
        },
      },
    });
  }

  Future<Map<String, dynamic>> getMetadata(String propertyId) async {
    final res = await _authClient!.get(Uri.parse('$_analyticsUrl/properties/$propertyId/metadata'));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> batchRunReports(
    String propertyId,
    List<Map<String, dynamic>> requests,
  ) async {
    final res = await _authClient!.post(
      Uri.parse('$_analyticsUrl/properties/$propertyId:batchRunReports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'requests': requests}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> runPivotReport(
    String propertyId,
    Map<String, dynamic> requestBody,
  ) async {
    final res = await _authClient!.post(
      Uri.parse('$_analyticsUrl/properties/$propertyId:runPivotReport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> runReport(
    String propertyId,
    Map<String, dynamic> requestBody,
  ) async {
    return _runReport(propertyId, requestBody);
  }

  Future<Map<String, dynamic>> runRealtimeReport(
    String propertyId,
    Map<String, dynamic> requestBody,
  ) async {
    final res = await _authClient!.post(
      Uri.parse('$_analyticsUrl/properties/$propertyId:runRealtimeReport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> collectAnalyticsData(String propertyId) async {
    final results = await Future.wait([
      getUsersPerCountry(propertyId),
      getTotalInstalls(propertyId),
      getLiveUsers(propertyId),
      getDailyActiveUsers(propertyId),
      getWeeklyActiveUsers(propertyId),
      getMonthlyActiveUsers(propertyId),
      getDailyInstalls(propertyId),
      getWeeklyInstalls(propertyId),
      getMonthlyInstalls(propertyId),
    ]);

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'usersPerCountry': formatDimensionMetric(results[0]),
      'totalInstalls': extractSingleMetric(results[1]),
      'liveUsers': formatDimensionMetric(results[2]),
      'dailyActiveUsers': extractSingleMetric(results[3]),
      'weeklyActiveUsers': extractSingleMetric(results[4]),
      'monthlyActiveUsers': extractSingleMetric(results[5]),
      'dailyInstalls': extractSingleMetric(results[6]),
      'weeklyInstalls': extractSingleMetric(results[7]),
      'monthlyInstalls': extractSingleMetric(results[8]),
    };
  }

  List<Map<String, dynamic>> formatDimensionMetric(Map<String, dynamic> data) {
    final rows = data['rows'] as List?;
    final dimHeaders = data['dimensionHeaders'] as List?;
    final metricHeaders = data['metricHeaders'] as List?;

    if (rows == null || dimHeaders == null || metricHeaders == null) return [];

    return rows.map((row) {
      final entry = <String, dynamic>{};

      final dimValues = row['dimensionValues'] as List;
      for (var i = 0; i < dimValues.length; i++) {
        final dimName = dimHeaders[i]['name'];
        entry[dimName] = dimValues[i]['value'];
      }

      final metricValues = row['metricValues'] as List;
      for (var i = 0; i < metricValues.length; i++) {
        final metricName = metricHeaders[i]['name'];
        entry[metricName] = metricValues[i]['value'];
      }

      return entry;
    }).toList();
  }

  Map<String, String> extractSingleMetric(Map<String, dynamic> data) {
    final rows = data['rows'] as List?;
    final metricHeaders = data['metricHeaders'] as List?;

    if (rows == null || metricHeaders == null) {
      return {'eventCount': '0'};
    }

    final metricName = metricHeaders[0]['name'] as String;
    final value = rows[0]['metricValues'][0]['value'] as String;
    return {metricName: value};
  }

  void dispose() {
    _authClient?.close();
  }
}
