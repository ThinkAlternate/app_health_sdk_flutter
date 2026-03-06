import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:app_health_sdk/app_health_sdk.dart';
import 'package:app_health_sdk/src/collectors/authentication/auth_session.dart';
import 'package:app_health_sdk/src/collectors/firebase/firebase_collector.dart';
import 'package:app_health_sdk/src/collectors/github/github_collector.dart';
import 'package:app_health_sdk/src/collectors/playstore/playstore_collector.dart';
import 'package:app_health_sdk/src/dashboard/database/uploaders.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

class AppHealthSDKImpl {
  final String apiUrl;
  final String apiKey;
  late final AppHealthConfig config;
  Timer? _syncTimer;

  AppHealthSDKImpl({required this.apiUrl, required this.apiKey, AppHealthConfig? config}) {
    if (config != null) {
      this.config = config;
    }
  }

  Future<void> init() async {
    // Fetch config if not provided
    try {
      final service = ProjectService(apiUrl);
      final configData = await service.fetchConfig(apiKey);
      log('config: $configData');
      config = AppHealthConfig.fromJson(configData['config']);
      // config = AppHealthConfig.fromJson(newConfig);
    } catch (e) {
      log('Failed to fetch config: $e');
      // Handle error or throw
      rethrow;
    }

    // Initialize Workmanager for background tasks
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<void> login(String email, String password) async {
    log("login requeaast: ${jsonEncode({'email': email, 'password': password})}");
    log("login url: $apiUrl/api/app-health-sdk/login");
    final response = await http.post(
      Uri.parse('$apiUrl/api/app-health-sdk/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    // log("login data: ${response.body}");

    if (response.statusCode >= 400) {
      throw Exception('Login failed: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    log("login data: ${data['userId']}");
    await SessionManager.saveSession({'userId': data['userId'], 'token': data['token']});
  }

  Future<void> startBackgroundService(Duration interval) async {
    // Register periodic task
    await Workmanager().registerPeriodicTask(
      'app-health-sync',
      'syncData',
      frequency: interval,
      inputData: {
        'apiUrl': apiUrl,
        'apiKey': apiKey,
        // Since config is fetched, we can pass it here to avoid re-fetching in background immediately,
        // or just pass apiKey and let background worker fetch it if needed.
        // For efficiency, passing the current config is better.
        // Convert to string to avoid platform channel serialization issues with nested maps
        'config': jsonEncode(config.toJson()),
      },
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> syncData() async {
    final isLoggedIn = await SessionManager.isLoggedIn();
    if (!isLoggedIn) {
      log("User not logged in. Skipping sync.");
      return;
    }

    final service = ProjectService(apiUrl);

    // Collect and upload GitHub data
    if (config.github != null) {
      final github = GitHubCollector(config.github!.token);
      final data = await github.collectRepoData(config.github!.owner, config.github!.repo);
      // log("aaaa-- $data");
      await service.uploadGitHubData(
        data,
        config.projectName,
        'flutter',
        '${config.github!.owner}/${config.github!.repo}',
      );
    }

    // Collect and upload Firebase data
    if (config.firebase != null) {
      final firebase = FirebaseCollector(
        serviceAccountKey: config.firebase!.credentials,
        projectId: config.firebase!.projectId,
      );
      await firebase.initialize();
      final analytics = await firebase.collectAnalyticsData(config.firebase!.propertyId);
      await service.uploadAnalytics(
        config.projectName,
        config.playStore?.packageName ?? '',
        analytics,
      );
    }

    // Add PlayStore, AppStore collectors similarly
    if (config.playStore != null) {
      final playStore = PlayConsoleCollector(
        serviceAccountKey: config.playStore!.serviceAccountKey,
        packageName: config.playStore!.packageName,
      );
      await playStore.init();
      final pricing = await playStore.getPricing(); // Used below now
      // await service.uploadPlayStoreData(config.projectName, 'mobile', pricing);
      log('Play store pricing: $pricing');
    }
  }

  Future<void> stopBackgroundService() async {
    await Workmanager().cancelAll();
    _syncTimer?.cancel();
  }
}

// Background callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Perform sync in background
    final impl = AppHealthSDKImpl(
      apiUrl: inputData!['apiUrl'],
      apiKey: inputData['apiKey'] ?? '', // Handle missing API key gracefully if possible
      config: AppHealthConfig.fromJson(jsonDecode(inputData['config'])),
    );
    await impl.syncData();
    return Future.value(true);
  });
}
