import 'package:app_health_sdk/app_health_sdk.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Example initialization
  // Replace with real values to test
  await AppHealthSDK.initialize(apiUrl: 'https://api.example.com', apiKey: 'your_api_key_here');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App Health SDK Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('SDK Initialized'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await AppHealthSDK.login('test@example.com', 'password');
                    debugPrint('Login successful');
                  } catch (e) {
                    debugPrint('Login failed: $e');
                  }
                },
                child: const Text('Test Login'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await AppHealthSDK.syncNow();
                    debugPrint('Sync successful');
                  } catch (e) {
                    debugPrint('Sync failed: $e');
                  }
                },
                child: const Text('Test Sync'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
