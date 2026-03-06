# App Health SDK for Flutter

A comprehensive Flutter SDK for monitoring and analyzing mobile app health across multiple platforms including Firebase, GitHub, Google Play Store, and Apple App Store. Provides automated dependency management, performance monitoring, and health analytics.

## Features

### 📊 Multi-Platform Analytics
- **Firebase Integration**: Crash analytics, performance monitoring, and user behavior tracking
- **GitHub Analytics**: Repository insights, commit history, and code quality metrics
- **Google Play Store**: App ratings, reviews, and download statistics
- **Apple App Store**: App ratings, reviews, and performance metrics

### 🔧 Automated Dependency Management
- **Smart Dependency Upgrades**: Automatic detection and upgrading of outdated dependencies
- **Security Vulnerability Scanning**: Identify and address security issues in dependencies
- **Performance Optimization**: Recommendations for dependency-related performance improvements

### 📈 Performance Monitoring
- **Real-time Metrics**: Continuous monitoring of app performance indicators
- **Crash Analysis**: Detailed crash reports and trend analysis
- **Recommendation Engine**: AI-powered suggestions for app health improvements

### 🔄 Background Synchronization
- **Automatic Data Sync**: Background synchronization with configurable intervals
- **Offline Support**: Local data storage with automatic upload when online
- **Efficient Resource Usage**: Optimized background processing to minimize battery impact

## Getting Started

### Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  app_health_sdk: ^0.0.1
```

### Basic Usage

1. **Initialize the SDK** in your `main()` function:

```dart
import 'package:app_health_sdk/app_health_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AppHealthSDK.initialize(
    apiUrl: 'https://api.apphealth.thinkalternate.com',
    apiKey: 'your-api-key',
    enableBackgroundSync: true,
    syncInterval: const Duration(hours: 1),
  );
  
  runApp(MyApp());
}
```

2. **Login User** (optional, for authenticated features):

```dart
try {
  await AppHealthSDK.login('user@example.com', 'password');
  print('User logged in successfully');
} catch (e) {
  print('Login failed: $e');
}
```

3. **Manual Sync** (optional):

```dart
try {
  await AppHealthSDK.syncNow();
  print('Data synchronized successfully');
} catch (e) {
  print('Sync failed: $e');
}
```

4. **Cleanup** (when app closes):

```dart
@override
void dispose() {
  AppHealthSDK.dispose();
  super.dispose();
}
```

## Configuration

### AppHealthConfig

Configure the SDK with custom settings:

```dart
final config = AppHealthConfig(
  firebaseConfig: FirebaseConfig(
    projectId: 'your-project-id',
    apiKey: 'your-api-key',
    // ... other Firebase settings
  ),
  githubConfig: GithubConfig(
    token: 'your-github-token',
    repository: 'owner/repo-name',
  ),
  playStoreConfig: PlayStoreConfig(
    packageName: 'com.example.app',
    credentialsPath: 'path/to/service-account.json',
  ),
  appStoreConfig: AppStoreConfig(
    bundleId: 'com.example.app',
    issuerId: 'your-issuer-id',
    privateKeyId: 'your-private-key-id',
    privateKeyPath: 'path/to/private-key.p8',
  ),
);
```

## API Reference

### AppHealthSDK

The main SDK class providing all functionality:

- `initialize()`: Initialize the SDK with configuration
- `login()`: Authenticate user for premium features
- `syncNow()`: Trigger manual data synchronization
- `dispose()`: Clean up resources and stop background services

### Collectors

Individual data collectors for each platform:

- `FirebaseCollector`: Firebase Analytics and Crashlytics data
- `GithubCollector`: GitHub repository and code metrics
- `PlayStoreCollector`: Google Play Store statistics
- `AppStoreCollector`: Apple App Store statistics

### Analyzers

Data analysis and recommendation engines:

- `CrashAnalyzer`: Analyze crash patterns and trends
- `PerformanceAnalyzer`: Monitor and analyze performance metrics
- `RecommendationEngine`: Generate health improvement suggestions

## Background Services

The SDK includes automatic background synchronization:

- **WorkManager Integration**: Uses Flutter WorkManager for reliable background execution
- **Configurable Intervals**: Set custom sync intervals (default: 1 hour)
- **Battery Optimized**: Respects device battery optimization settings
- **Network Aware**: Only syncs when connected to Wi-Fi (configurable)

## Data Privacy

- **Local Storage**: All data is stored locally on the device
- **Secure Transmission**: HTTPS encryption for all API communications
- **User Consent**: Respects user privacy preferences and permissions
- **Data Minimization**: Only collects necessary data for health analysis

## Requirements

- Flutter 1.17.0 or higher
- Dart 2.12.0 or higher
- Android API 21+ (for Android builds)
- iOS 11.0+ (for iOS builds)

## Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web (limited functionality)
- ✅ Desktop (limited functionality)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions:

- 📧 Email: support@apphealth.thinkalternate.com
- 🌐 Website: https://apphealth.thinkalternate.com
- 📖 Documentation: [API Documentation](https://apphealth.thinkalternate.com/docs)

## Changelog

See the [CHANGELOG.md](CHANGELOG.md) file for details on version updates and changes.

## Security

If you discover a security vulnerability, please report it to security@apphealth.thinkalternate.com

---

**Built with ❤️ by ThinkAlternate**

For more information, visit [apphealth.thinkalternate.com](https://apphealth.thinkalternate.com)