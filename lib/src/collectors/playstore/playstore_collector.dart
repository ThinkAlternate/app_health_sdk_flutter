import 'dart:convert';

import 'package:flutter/foundation.dart';
// import 'package:googleapis/playdeveloperreporting/v1beta1.dart' as reporting;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class PlayStoreVitals {
  final Map<String, dynamic> anr;
  final Map<String, dynamic> crash;
  final List<dynamic>? errorReports;
  final List<dynamic>? errorIssues;

  PlayStoreVitals({required this.anr, required this.crash, this.errorReports, this.errorIssues});
}

class PlayStorePricing {
  final List<dynamic> inAppProducts;
  final List<dynamic> subscriptions;

  PlayStorePricing({required this.inAppProducts, required this.subscriptions});
}

class PlayConsoleCollector {
  final Map<String, dynamic> serviceAccountKey;
  final String packageName;
  static const String _baseUrl = 'https://playdeveloperreporting.googleapis.com/v1beta1';
  static const String _publisherUrl = 'https://androidpublisher.googleapis.com/androidpublisher/v3';

  AutoRefreshingAuthClient? _authClient;

  PlayConsoleCollector({required this.serviceAccountKey, required this.packageName});

  Future<void> init() async {
    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountKey);
    final scopes = [
      'https://www.googleapis.com/auth/playdeveloperreporting',
      'https://www.googleapis.com/auth/androidpublisher',
    ];

    _authClient = await clientViaServiceAccount(accountCredentials, scopes);
    debugPrint('✅ Google Play clients initialized');
  }

  Future<PlayStoreVitals> getVitals(DateTime startDate, DateTime endDate) async {
    if (_authClient == null) {
      throw StateError('Client not initialized. Call init() first.');
    }

    try {
      // Query ANR rates
      final anrRequest = {
        'metrics': ['anrRate', 'userPerceivedAnrRate', 'distinctUsers'],
        'dimensions': ['deviceModel'],
        'timelineSpec': {
          'aggregationPeriod': 'DAILY',
          'startTime': {'year': startDate.year, 'month': startDate.month, 'day': startDate.day},
          'endTime': {'year': endDate.year, 'month': endDate.month, 'day': endDate.day - 1},
        },
      };

      final anrRes = await _authClient!.post(
        Uri.parse('$_baseUrl/apps/$packageName/anrRateMetricSet:query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(anrRequest),
      );

      // Query crash rates
      final crashRequest = {
        'metrics': ['crashRate', 'distinctUsers'],
        'dimensions': ['versionCode', 'apiLevel', 'deviceModel'],
        'timelineSpec': {
          'aggregationPeriod': 'DAILY',
          'startTime': {'year': startDate.year, 'month': startDate.month, 'day': startDate.day},
          'endTime': {'year': endDate.year, 'month': endDate.month, 'day': endDate.day - 1},
        },
      };

      final crashRes = await _authClient!.post(
        Uri.parse('$_baseUrl/apps/$packageName/crashRateMetricSet:query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(crashRequest),
      );

      // Search error reports
      final errorReportsUri = Uri.parse('$_baseUrl/apps/$packageName/errorReports:search').replace(
        queryParameters: {
          'filter': 'errorIssueType = "CRASH"',
          'pageSize': '100',
          'interval.startTime.year': startDate.year.toString(),
          'interval.startTime.month': startDate.month.toString(),
          'interval.startTime.day': startDate.day.toString(),
          'interval.endTime.year': endDate.year.toString(),
          'interval.endTime.month': endDate.month.toString(),
          'interval.endTime.day': endDate.day.toString(),
        },
      );

      final errorsRes = await _authClient!.get(errorReportsUri);

      // Search error issues
      final errorIssuesUri = Uri.parse('$_baseUrl/apps/$packageName/errorIssues:search').replace(
        queryParameters: {
          'filter': 'errorIssueType = "CRASH"',
          'interval.startTime.year': startDate.year.toString(),
          'interval.startTime.month': startDate.month.toString(),
          'interval.startTime.day': startDate.day.toString(),
          'interval.endTime.year': endDate.year.toString(),
          'interval.endTime.month': endDate.month.toString(),
          'interval.endTime.day': endDate.day.toString(),
        },
      );

      final issuesRes = await _authClient!.get(errorIssuesUri);

      return PlayStoreVitals(
        anr: jsonDecode(anrRes.body),
        crash: jsonDecode(crashRes.body),
        errorReports: (jsonDecode(errorsRes.body)['errorReports'] as List?)
            ?.cast<Map<String, dynamic>>(),
        errorIssues: (jsonDecode(issuesRes.body)['errorIssues'] as List?)
            ?.cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      debugPrint('❌ Error fetching vitals: $e');
      rethrow;
    }
  }

  Future<PlayStorePricing> getPricing() async {
    if (_authClient == null) {
      throw StateError('Client not initialized. Call init() first.');
    }

    try {
      // Fetch in-app products
      final inAppRes = await _authClient!.get(
        Uri.parse('$_publisherUrl/applications/$packageName/inappproducts'),
      );

      // Fetch subscriptions
      final subRes = await _authClient!.get(
        Uri.parse('$_publisherUrl/applications/$packageName/subscriptions'),
      );

      return PlayStorePricing(
        inAppProducts:
            (jsonDecode(inAppRes.body)['inappproduct'] as List?)?.cast<Map<String, dynamic>>() ??
            [],
        subscriptions:
            (jsonDecode(subRes.body)['subscription'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      );
    } catch (e) {
      debugPrint('❌ Error fetching pricing: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAppDetails(String appPackageName) async {
    try {
      // Using google-play-scraper equivalent
      // Note: Dart doesn't have a direct equivalent, so using HTTP directly
      final response = await http.get(
        Uri.parse('https://play.google.com/store/apps/details?id=$appPackageName&hl=en&gl=us'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch app details');
      }

      // Parse basic info from HTML (simplified - you may want to use a proper scraper package)
      // For production, consider using a package like 'html' for parsing
      return {
        'app_info': {
          'package_name': appPackageName,
          'url': 'https://play.google.com/store/apps/details?id=$appPackageName',
          // Add more parsing logic here
        },
      };
    } catch (e) {
      debugPrint('❌ Error fetching app details: $e');
      rethrow;
    }
  }

  void dispose() {
    _authClient?.close();
  }
}
