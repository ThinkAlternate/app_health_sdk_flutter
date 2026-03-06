import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class DetectionResult {
  final bool detected;
  final String type;
  final double confidence;
  final Map<String, dynamic>? details;

  DetectionResult({required this.detected, required this.type, this.confidence = 0, this.details});
}

class ProjectInfo {
  final String primaryType;
  final List<DetectionResult> allTypes;
  final DetectionResult projectInfo;
  final List<String> recommendations;

  ProjectInfo({
    required this.primaryType,
    required this.allTypes,
    required this.projectInfo,
    required this.recommendations,
  });
}

class ProjectDetector {
  final String projectPath;
  final List<DetectionResult> detectedTypes = [];
  late DetectionResult projectInfo;

  ProjectDetector({String? projectPath}) : projectPath = projectPath ?? Directory.current.path;

  Future<ProjectInfo> detectProject() async {
    debugPrint('🔍 Analyzing project at: $projectPath\n');

    final detectors = [
      detectReactNative,
      detectFlutter,
      detectAndroidNative,
      detectiOSNative,
      detectReact,
      detectNodeJS,
      detectNextJS,
      detectVue,
      detectAngular,
      detectJetpackCompose,
    ];

    for (final detector in detectors) {
      try {
        final result = await detector();
        if (result.detected) {
          detectedTypes.add(result);
        }
      } catch (e) {
        debugPrint('Warning: Error in detector: $e');
      }
    }

    projectInfo = determinePrimaryType();

    return ProjectInfo(
      primaryType: projectInfo.type,
      allTypes: detectedTypes,
      projectInfo: projectInfo,
      recommendations: generateRecommendations(),
    );
  }

  bool fileExists(String filePath) {
    return File(path.join(projectPath, filePath)).existsSync();
  }

  bool dirExists(String dirPath) {
    final dir = Directory(path.join(projectPath, dirPath));
    return dir.existsSync();
  }

  Map<String, dynamic>? readJsonFile(String filePath) {
    try {
      final file = File(path.join(projectPath, filePath));
      if (file.existsSync()) {
        return jsonDecode(file.readAsStringSync());
      }
    } catch (e) {
      debugPrint('Could not parse $filePath: $e');
    }
    return null;
  }

  String? readTextFile(String filePath) {
    try {
      final file = File(path.join(projectPath, filePath));
      if (file.existsSync()) {
        return file.readAsStringSync();
      }
    } catch (e) {
      debugPrint('Could not read $filePath: $e');
    }
    return null;
  }

  List<String> findFiles(String pattern) {
    try {
      final result = Process.runSync('find', [
        projectPath,
        '-name',
        pattern,
        '-type',
        'f',
      ], runInShell: true);
      return (result.stdout as String).trim().split('\n').where((line) => line.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<DetectionResult> detectReactNative() async {
    final packageJson = readJsonFile('package.json');

    final indicators = {
      'hasPackageJson': packageJson != null,
      'hasReactNative':
          packageJson?['dependencies']?['react-native'] != null ||
          packageJson?['devDependencies']?['react-native'] != null,
      'hasAndroidDir': dirExists('android'),
      'hasiOSDir': dirExists('ios'),
      'hasMetroConfig': fileExists('metro.config.js') || fileExists('metro.config.ts'),
      'hasReactNativeConfig': fileExists('react-native.config.js'),
      'hasAppJson': fileExists('app.json'),
      'hasExpo':
          packageJson?['dependencies']?['expo'] != null ||
          packageJson?['devDependencies']?['expo'] != null,
    };

    final score = indicators.values.where((v) => v).length;
    final isReactNative =
        indicators['hasPackageJson']! && indicators['hasReactNative']! && score >= 3;

    if (isReactNative) {
      final rnVersion =
          packageJson?['dependencies']?['react-native'] ??
          packageJson?['devDependencies']?['react-native'];

      return DetectionResult(
        detected: true,
        type: 'react-native',
        confidence: (score / 6 * 100).clamp(0, 100),
        details: {
          'version': rnVersion,
          'isExpo': indicators['hasExpo'],
          'hasNativeCode': indicators['hasAndroidDir']! && indicators['hasiOSDir']!,
          'framework': indicators['hasExpo']! ? 'Expo' : 'React Native CLI',
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'react-native');
  }

  Future<DetectionResult> detectFlutter() async {
    final pubspecContent = readTextFile('pubspec.yaml');

    final indicators = {
      'hasPubspec': pubspecContent != null,
      'hasFlutterSdk': pubspecContent?.contains('flutter:') ?? false,
      'hasLibDir': dirExists('lib'),
      'hasAndroidDir': dirExists('android'),
      'hasiOSDir': dirExists('ios'),
      'hasDartFiles': findFiles('*.dart').isNotEmpty,
      'hasMainDart': fileExists('lib/main.dart'),
    };

    final score = indicators.values.where((v) => v).length;
    final isFlutter = indicators['hasPubspec']! && indicators['hasFlutterSdk']! && score >= 4;

    if (isFlutter) {
      final flutterVersionMatch = RegExp(r'flutter:\s*"([^"]+)"').firstMatch(pubspecContent!);
      final dartVersionMatch = RegExp(r'sdk:\s*"([^"]+)"').firstMatch(pubspecContent);

      return DetectionResult(
        detected: true,
        type: 'flutter',
        confidence: (score / 7 * 100).clamp(0, 100),
        details: {
          'flutterVersion': flutterVersionMatch?.group(1) ?? 'unknown',
          'dartVersion': dartVersionMatch?.group(1) ?? 'unknown',
          'hasNativeIntegration': indicators['hasAndroidDir']! && indicators['hasiOSDir']!,
          'dartFileCount': findFiles('*.dart').length,
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'flutter');
  }

  Future<DetectionResult> detectAndroidNative() async {
    final indicators = {
      'hasBuildGradle': fileExists('build.gradle') || fileExists('build.gradle.kts'),
      'hasAppBuildGradle': fileExists('app/build.gradle') || fileExists('app/build.gradle.kts'),
      'hasAndroidManifest': fileExists('app/src/main/AndroidManifest.xml'),
      'hasJavaSource': dirExists('app/src/main/java'),
      'hasKotlinSource': dirExists('app/src/main/kotlin') || findFiles('*.kt').isNotEmpty,
      'hasResources': dirExists('app/src/main/res'),
      'hasGradleWrapper': fileExists('gradlew'),
    };

    final score = indicators.values.where((v) => v).length;
    final isAndroid =
        indicators['hasBuildGradle']! && indicators['hasAndroidManifest']! && score >= 4;

    if (isAndroid) {
      final buildGradle = readTextFile('app/build.gradle') ?? readTextFile('app/build.gradle.kts');
      final isCompose = buildGradle?.contains('compose') ?? false;
      final language = indicators['hasKotlinSource']! ? 'Kotlin' : 'Java';

      return DetectionResult(
        detected: true,
        type: 'android-native',
        confidence: (score / 7 * 100).clamp(0, 100),
        details: {
          'language': language,
          'hasJetpackCompose': isCompose,
          'buildSystem': 'Gradle',
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'android-native');
  }

  Future<DetectionResult> detectiOSNative() async {
    final xcodeProjects = findFiles('*.xcodeproj');
    final xcodeWorkspaces = findFiles('*.xcworkspace');

    final indicators = {
      'hasXcodeProject': xcodeProjects.isNotEmpty,
      'hasXcodeWorkspace': xcodeWorkspaces.isNotEmpty,
      'hasSwiftFiles': findFiles('*.swift').isNotEmpty,
      'hasObjCFiles': findFiles('*.m').isNotEmpty,
      'hasInfoPlist': fileExists('Info.plist') || findFiles('Info.plist').isNotEmpty,
      'hasPodfile': fileExists('Podfile'),
      'hasPackageSwift': fileExists('Package.swift'),
    };

    final score = indicators.values.where((v) => v).length;
    final isiOS = indicators['hasXcodeProject']! && score >= 3;

    if (isiOS) {
      final language = indicators['hasSwiftFiles']!
          ? 'Swift'
          : indicators['hasObjCFiles']!
          ? 'Objective-C'
          : 'Unknown';

      return DetectionResult(
        detected: true,
        type: 'ios-native',
        confidence: (score / 7 * 100).clamp(0, 100),
        details: {
          'language': language,
          'hasCocoaPods': indicators['hasPodfile'],
          'hasSwiftPackageManager': indicators['hasPackageSwift'],
          'projectCount': xcodeProjects.length,
          'workspaceCount': xcodeWorkspaces.length,
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'ios-native');
  }

  Future<DetectionResult> detectReact() async {
    final packageJson = readJsonFile('package.json');

    final indicators = {
      'hasPackageJson': packageJson != null,
      'hasReact':
          packageJson?['dependencies']?['react'] != null ||
          packageJson?['devDependencies']?['react'] != null,
      'hasReactDOM':
          packageJson?['dependencies']?['react-dom'] != null ||
          packageJson?['devDependencies']?['react-dom'] != null,
      'hasReactScripts':
          packageJson?['dependencies']?['react-scripts'] != null ||
          packageJson?['devDependencies']?['react-scripts'] != null,
      'hasPublicDir': dirExists('public'),
      'hasSrcDir': dirExists('src'),
      'hasIndexHtml': fileExists('public/index.html'),
      'hasJSXFiles': findFiles('*.jsx').isNotEmpty || findFiles('*.tsx').isNotEmpty,
      'notReactNative': packageJson?['dependencies']?['react-native'] == null,
      'notNextJS': packageJson?['dependencies']?['next'] == null,
    };

    final score = indicators.values.where((v) => v).length;
    final isReact =
        indicators['hasPackageJson']! &&
        indicators['hasReact']! &&
        indicators['notReactNative']! &&
        indicators['notNextJS']! &&
        score >= 5;

    if (isReact) {
      final reactVersion =
          packageJson?['dependencies']?['react'] ?? packageJson?['devDependencies']?['react'];
      final isCRA = indicators['hasReactScripts']!;

      return DetectionResult(
        detected: true,
        type: 'react',
        confidence: (score / 9 * 100).clamp(0, 100),
        details: {
          'version': reactVersion,
          'isCreateReactApp': isCRA,
          'hasTypeScript': fileExists('tsconfig.json'),
          'bundler': isCRA ? 'Create React App' : 'Custom',
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'react');
  }

  Future<DetectionResult> detectNextJS() async {
    final packageJson = readJsonFile('package.json');

    final indicators = {
      'hasPackageJson': packageJson != null,
      'hasNext':
          packageJson?['dependencies']?['next'] != null ||
          packageJson?['devDependencies']?['next'] != null,
      'hasReact':
          packageJson?['dependencies']?['react'] != null ||
          packageJson?['devDependencies']?['react'] != null,
      'hasNextConfig': fileExists('next.config.js') || fileExists('next.config.mjs'),
      'hasPagesDir': dirExists('pages'),
      'hasAppDir': dirExists('app'),
      'hasPublicDir': dirExists('public'),
      'hasNextScripts':
          packageJson?['scripts']?['dev']?.contains('next') == true ||
          packageJson?['scripts']?['build']?.contains('next') == true,
    };

    final score = indicators.values.where((v) => v).length;
    final isNextJS = indicators['hasNext']! && indicators['hasReact']! && score >= 4;

    if (isNextJS) {
      final nextVersion =
          packageJson?['dependencies']?['next'] ?? packageJson?['devDependencies']?['next'];
      final routingType = indicators['hasAppDir']!
          ? 'App Router'
          : indicators['hasPagesDir']!
          ? 'Pages Router'
          : 'Unknown';

      return DetectionResult(
        detected: true,
        type: 'nextjs',
        confidence: (score / 8 * 100).clamp(0, 100),
        details: {
          'version': nextVersion,
          'routingType': routingType,
          'hasTypeScript': fileExists('tsconfig.json'),
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'nextjs');
  }

  Future<DetectionResult> detectNodeJS() async {
    final packageJson = readJsonFile('package.json');

    final indicators = {
      'hasPackageJson': packageJson != null,
      'hasMainField': packageJson?['main'] != null,
      'hasNodeScripts':
          (packageJson?['scripts'] as Map?)?.values.any(
            (script) => script.toString().contains('node'),
          ) ??
          false,
      'hasServerFiles':
          fileExists('server.js') ||
          fileExists('index.js') ||
          fileExists('app.js') ||
          fileExists('main.js'),
      'hasExpress':
          packageJson?['dependencies']?['express'] != null ||
          packageJson?['devDependencies']?['express'] != null,
      'hasFastify':
          packageJson?['dependencies']?['fastify'] != null ||
          packageJson?['devDependencies']?['fastify'] != null,
      'hasNestJS':
          packageJson?['dependencies']?['@nestjs/core'] != null ||
          packageJson?['devDependencies']?['@nestjs/core'] != null,
      'notReact': packageJson?['dependencies']?['react'] == null,
      'notVue': packageJson?['dependencies']?['vue'] == null,
      'notAngular': packageJson?['dependencies']?['@angular/core'] == null,
    };

    final score = indicators.values.where((v) => v).length;
    final isNodeJS =
        indicators['hasPackageJson']! &&
        indicators['notReact']! &&
        indicators['notVue']! &&
        indicators['notAngular']! &&
        score >= 4;

    if (isNodeJS) {
      final nodeVersion = packageJson?['engines']?['node'] ?? 'unknown';
      final framework = indicators['hasNestJS']!
          ? 'NestJS'
          : indicators['hasExpress']!
          ? 'Express'
          : indicators['hasFastify']!
          ? 'Fastify'
          : 'Vanilla Node.js';

      return DetectionResult(
        detected: true,
        type: 'nodejs',
        confidence: (score / 9 * 100).clamp(0, 100),
        details: {
          'nodeVersion': nodeVersion,
          'framework': framework,
          'hasTypeScript': fileExists('tsconfig.json'),
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'nodejs');
  }

  Future<DetectionResult> detectVue() async {
    final packageJson = readJsonFile('package.json');

    final indicators = {
      'hasPackageJson': packageJson != null,
      'hasVue':
          packageJson?['dependencies']?['vue'] != null ||
          packageJson?['devDependencies']?['vue'] != null,
      'hasVueCLI': packageJson?['devDependencies']?['@vue/cli-service'] != null,
      'hasVite':
          packageJson?['devDependencies']?['vite'] != null &&
          packageJson?['devDependencies']?['@vitejs/plugin-vue'] != null,
      'hasVueFiles': findFiles('*.vue').isNotEmpty,
      'hasSrcDir': dirExists('src'),
      'hasPublicDir': dirExists('public'),
    };

    final score = indicators.values.where((v) => v).length;
    final isVue = indicators['hasVue']! && score >= 3;

    if (isVue) {
      final vueVersion =
          packageJson?['dependencies']?['vue'] ?? packageJson?['devDependencies']?['vue'];
      final buildTool = indicators['hasVite']!
          ? 'Vite'
          : indicators['hasVueCLI']!
          ? 'Vue CLI'
          : 'Custom';

      return DetectionResult(
        detected: true,
        type: 'vue',
        confidence: (score / 7 * 100).clamp(0, 100),
        details: {
          'version': vueVersion,
          'buildTool': buildTool,
          'hasTypeScript': fileExists('tsconfig.json'),
          'vueFileCount': findFiles('*.vue').length,
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'vue');
  }

  Future<DetectionResult> detectAngular() async {
    final packageJson = readJsonFile('package.json');
    final angularJson = readJsonFile('angular.json');

    final indicators = {
      'hasPackageJson': packageJson != null,
      'hasAngularCore': packageJson?['dependencies']?['@angular/core'] != null,
      'hasAngularCLI': packageJson?['devDependencies']?['@angular/cli'] != null,
      'hasAngularJson': angularJson != null,
      'hasTsConfig': fileExists('tsconfig.json'),
      'hasSrcApp': dirExists('src/app'),
      'hasAngularFiles': findFiles('*.component.ts').isNotEmpty,
    };

    final score = indicators.values.where((v) => v).length;
    final isAngular = indicators['hasAngularCore']! && score >= 4;

    if (isAngular) {
      final angularVersion = packageJson?['dependencies']?['@angular/core'];

      return DetectionResult(
        detected: true,
        type: 'angular',
        confidence: (score / 7 * 100).clamp(0, 100),
        details: {
          'version': angularVersion,
          'hasAngularCLI': indicators['hasAngularCLI'],
          'componentCount': findFiles('*.component.ts').length,
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'angular');
  }

  Future<DetectionResult> detectJetpackCompose() async {
    final buildGradle = readTextFile('app/build.gradle') ?? readTextFile('app/build.gradle.kts');

    final indicators = {
      'hasBuildGradle': buildGradle != null,
      'usesVersionCatalog':
          buildGradle?.contains('libs.androidx.activity.compose') == true ||
          buildGradle?.contains('platform(libs.androidx.compose.bom)') == true,
      'hasComposeActivity':
          buildGradle?.contains('androidx.activity:activity-compose') == true ||
          buildGradle?.contains('libs.androidx.activity.compose') == true,
      'hasComposeBom':
          buildGradle?.contains('androidx.compose:compose-bom') == true ||
          buildGradle?.contains('platform(libs.androidx.compose.bom)') == true,
      'hasComposeUI':
          buildGradle?.contains('androidx.compose.ui:ui') == true ||
          buildGradle?.contains('libs.androidx.compose.ui') == true,
      'hasComposeMaterial':
          buildGradle?.contains('androidx.compose.material') == true ||
          buildGradle?.contains('libs.androidx.compose.material') == true,
      'hasComposeCompiler':
          buildGradle?.contains('composeCompilerExtension') == true ||
          buildGradle?.contains('compose true') == true ||
          buildGradle?.contains('kotlinCompilerExtensionVersion') == true,
      'hasComposeFiles': findFiles('*Compose*.kt').isNotEmpty,
    };

    final score = indicators.values.where((v) => v).length;
    final isCompose =
        indicators['hasBuildGradle']! &&
        (indicators['hasComposeBom']! || indicators['hasComposeUI']!) &&
        score >= 3;

    if (isCompose) {
      return DetectionResult(
        detected: true,
        type: 'jetpack-compose',
        confidence: (score / 7 * 100).clamp(0, 100),
        details: {
          'composeFileCount': findFiles('*Compose*.kt').length,
          'hasMaterial3': buildGradle?.contains('material3') ?? false,
          'indicators': indicators,
        },
      );
    }

    return DetectionResult(detected: false, type: 'jetpack-compose');
  }

  DetectionResult determinePrimaryType() {
    if (detectedTypes.isEmpty) {
      return DetectionResult(detected: false, type: 'unknown', confidence: 0);
    }

    final priorityOrder = {
      'react-native': 10,
      'flutter': 9,
      'nextjs': 8,
      'android-native': 7,
      'ios-native': 7,
      'react': 6,
      'vue': 5,
      'angular': 5,
      'nodejs': 4,
      'jetpack-compose': 3,
    };

    final sorted = List<DetectionResult>.from(detectedTypes)
      ..sort((a, b) {
        final priorityA = priorityOrder[a.type] ?? 0;
        final priorityB = priorityOrder[b.type] ?? 0;

        if (priorityA != priorityB) {
          return priorityB - priorityA;
        }

        return b.confidence.compareTo(a.confidence);
      });

    return sorted.first;
  }

  List<String> generateRecommendations() {
    final recommendations = <String>[];
    final primaryType = projectInfo.type;

    final typeRecommendations = {
      'react-native': [
        'Set up Firebase Crashlytics for crash reporting',
        'Configure Firebase Analytics for user behavior tracking',
        'Set up GitHub Actions for CI/CD',
        'Consider using Flipper for debugging',
        'Implement proper error boundaries',
      ],
      'flutter': [
        'Set up Firebase Crashlytics for Flutter',
        'Configure Firebase Analytics',
        'Set up GitHub Actions with Flutter CI/CD',
        'Consider using Firebase App Distribution',
        'Implement proper error handling with try-catch blocks',
      ],
      'android-native': [
        'Set up Firebase Crashlytics',
        'Configure Google Play Console for app vitals',
        'Set up GitHub Actions for Android CI/CD',
        'Consider implementing Jetpack Compose for modern UI',
        'Use ProGuard/R8 for code obfuscation',
      ],
      'ios-native': [
        'Set up Firebase Crashlytics for iOS',
        'Configure App Store Connect for analytics',
        'Set up GitHub Actions for iOS CI/CD',
        'Consider using SwiftUI for modern UI development',
        'Implement proper memory management',
      ],
      'react': [
        'Set up error boundaries for better error handling',
        'Configure GitHub Actions for web deployment',
        'Consider using React Query for data fetching',
        'Implement proper bundle optimization',
        'Set up performance monitoring',
      ],
      'nodejs': [
        'Set up error logging (Winston, Bunyan)',
        'Configure GitHub Actions for Node.js CI/CD',
        'Implement proper environment configuration',
        'Set up API monitoring and alerting',
        'Consider using PM2 for production deployment',
      ],
    };

    if (typeRecommendations.containsKey(primaryType)) {
      recommendations.addAll(typeRecommendations[primaryType]!);
    }

    return recommendations;
  }

  void debugPrintResults() {
    debugPrint('📊 PROJECT ANALYSIS RESULTS');
    debugPrint('=' * 50);

    if (detectedTypes.isEmpty) {
      debugPrint('❌ No known project types detected');
      return;
    }

    debugPrint('\n🎯 Primary Project Type: ${projectInfo.type.toUpperCase()}');
    debugPrint('📈 Confidence: ${projectInfo.confidence.toStringAsFixed(1)}%');

    if (projectInfo.details != null) {
      debugPrint('\n📋 Details:');
      projectInfo.details!.forEach((key, value) {
        if (key != 'indicators' && value != null) {
          debugPrint('   $key: $value');
        }
      });
    }

    if (detectedTypes.length > 1) {
      debugPrint('\n🔄 Other Detected Types:');
      for (final type in detectedTypes) {
        if (type.type != projectInfo.type) {
          debugPrint('   - ${type.type} (${type.confidence.toStringAsFixed(1)}%)');
        }
      }
    }

    final recommendations = generateRecommendations();
    if (recommendations.isNotEmpty) {
      debugPrint('\n💡 Recommendations:');
      for (var i = 0; i < recommendations.length; i++) {
        debugPrint('   ${i + 1}. ${recommendations[i]}');
      }
    }
  }
}
