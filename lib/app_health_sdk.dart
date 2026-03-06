import 'package:app_health_sdk/src/app_health_sdk_impl.dart';

export 'src/models/config.dart';

class AppHealthSDK {
  static final AppHealthSDK _instance = AppHealthSDK._internal();
  factory AppHealthSDK() => _instance;
  AppHealthSDK._internal();

  AppHealthSDKImpl? _impl;

  /// Initialize SDK - call once in main()
  static Future<void> initialize({
    required String apiUrl,
    required String apiKey,
    bool enableBackgroundSync = true,
    Duration syncInterval = const Duration(hours: 1),
  }) async {
    _instance._impl = AppHealthSDKImpl(apiUrl: apiUrl, apiKey: apiKey);

    await _instance._impl!.init();

    if (enableBackgroundSync) {
      await _instance._impl!.startBackgroundService(syncInterval);
    }
  }

  /// Login user
  static Future<void> login(String email, String password) async {
    if (_instance._impl == null) {
      throw Exception('SDK not initialized. Call initialize() first.');
    }
    await _instance._impl!.login(email, password);
  }

  /// Manual sync trigger
  static Future<void> syncNow() async {
    if (_instance._impl == null) {
      throw Exception('SDK not initialized. Call initialize() first.');
    }
    await _instance._impl!.syncData();
  }

  /// Stop background service
  static Future<void> dispose() async {
    if (_instance._impl != null) {
      await _instance._impl!.stopBackgroundService();
    }
  }
}
