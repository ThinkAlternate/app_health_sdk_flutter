import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class DependencyInfo {
  final String name;
  final String current;
  final String latest;
  final String? resolvable;
  final String? description;
  final String? severity;
  final String? downloads;
  final String? lastUpdate;
  final String? category;
  final bool? security;
  final bool? breaking;
  final String? reason;
  final String? target;

  DependencyInfo({
    required this.name,
    required this.current,
    required this.latest,
    this.resolvable,
    this.description,
    this.severity,
    this.downloads,
    this.lastUpdate,
    this.category,
    this.security,
    this.breaking,
    this.reason,
    this.target,
  });
}

class DependencyUpgrader {
  final String projectRoot;
  final String type;

  DependencyUpgrader({String? projectRoot, required this.type})
    : projectRoot = projectRoot ?? Directory.current.path;

  Future<List<DependencyInfo>> checkDependencies() async {
    switch (type) {
      case 'node':
      case 'react':
      case 'nextjs':
      case 'vue':
      case 'angular':
      case 'react-native':
        return await checkNpmDependencies();
      case 'flutter':
        return await checkFlutterDependencies();
      case 'android':
        return await checkAndroidDependencies();
      case 'ios':
        return await checkiOSDependencies();
      default:
        debugPrint('Unknown or unsupported project type');
        return [];
    }
  }

  Future<DependencyInfo?> getPackageMeta(String dep, String currentVersion) async {
    try {
      final registryUrl = 'https://registry.npmjs.org/$dep';
      final downloadsUrl = 'https://api.npmjs.org/downloads/point/last-week/$dep';

      final responses = await Future.wait([
        http.get(Uri.parse(registryUrl)),
        http.get(Uri.parse(downloadsUrl)),
      ]);

      final registryData = jsonDecode(responses[0].body);
      final downloadsData = jsonDecode(responses[1].body);

      final distTags = registryData['dist-tags'] ?? {};
      final latest = distTags['latest'];
      final versions = registryData['versions'] as Map<String, dynamic>;

      final stableVersion = _getStableVersion(versions, distTags, latest);
      final description = registryData['description'] ?? '';

      final modified = registryData['time']?['modified'];
      final lastUpdate = modified != null
          ? _formatDistanceToNow(DateTime.parse(modified))
          : 'unknown';

      final downloads = downloadsData['downloads'] != null
          ? '${(downloadsData['downloads'] / 1000).toStringAsFixed(1)}K'
          : 'N/A';

      return DependencyInfo(
        name: dep,
        latest: latest,
        current: currentVersion,
        resolvable: stableVersion,
        description: description,
        downloads: downloads,
        lastUpdate: lastUpdate,
        category: _inferCategory(dep),
        security: false,
      );
    } catch (e) {
      debugPrint('Failed to fetch $dep: $e');
      return null;
    }
  }

  String _getStableVersion(
    Map<String, dynamic> versions,
    Map<String, dynamic> distTags,
    String latest,
  ) {
    if (distTags.containsKey('stable')) {
      return distTags['stable'];
    }

    final stableTags = distTags.keys.where((tag) => tag.contains('-stable')).toList();

    if (stableTags.isNotEmpty) {
      stableTags.sort((a, b) => b.compareTo(a));
      return stableTags.first;
    }

    final versionList = versions.keys.toList()..sort((a, b) => b.compareTo(a));

    final stableVersion = versionList.firstWhere(
      (version) => !RegExp(
        r'(alpha|beta|rc|pre|dev|canary|next|nightly)',
        caseSensitive: false,
      ).hasMatch(version),
      orElse: () => latest,
    );

    return stableVersion;
  }

  String _formatDistanceToNow(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()} years ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inMinutes} minutes ago';
    }
  }

  String _inferCategory(String depName) {
    if (depName.contains('auth')) return 'Authentication';
    if (depName.contains('axios') || depName.contains('fetch')) return 'Networking';
    if (depName.contains('react-native')) return 'UI';
    return 'General';
  }

  Future<List<DependencyInfo>> checkNpmDependencies() async {
    final pkgPath = path.join(projectRoot, 'package.json');
    final file = File(pkgPath);

    if (!file.existsSync()) return [];

    final pkg = jsonDecode(await file.readAsString());
    final allDeps = <String, String>{...?pkg['dependencies'], ...?pkg['devDependencies']};

    final upgrades = await Future.wait(
      allDeps.entries.map((entry) => getPackageMeta(entry.key, entry.value)),
    );

    return upgrades.whereType<DependencyInfo>().toList();
  }

  Future<List<DependencyInfo>> checkFlutterDependencies() async {
    debugPrint('Checking Flutter dependencies...');

    try {
      final result = await Process.run('flutter', [
        'pub',
        'outdated',
        '--json',
      ], workingDirectory: projectRoot);

      if (result.exitCode != 0) {
        debugPrint('flutter pub outdated failed: ${result.stderr}');
        return [];
      }

      final data = jsonDecode(result.stdout);
      final packages = data['packages'] as List<dynamic>;
      final upgrades = <DependencyInfo>[];

      for (final pkg in packages) {
        final isDiscontinued = pkg['isDiscontinued'] ?? false;
        final isAffected = pkg['isCurrentAffectedByAdvisory'] ?? false;

        if (isDiscontinued) continue;

        if (isAffected && pkg['resolvable']?['version'] != pkg['current']?['version']) {
          upgrades.add(
            DependencyInfo(
              name: pkg['package'],
              reason: 'security_advisory',
              current: pkg['current']['version'],
              latest: pkg['latest']['version'],
              target: pkg['resolvable']['version'],
            ),
          );
          continue;
        }

        if (pkg['latest']?['version'] != null &&
            pkg['current']?['version'] != null &&
            pkg['latest']['version'] != pkg['current']['version']) {
          upgrades.add(
            DependencyInfo(
              name: pkg['package'],
              reason: 'outdated',
              current: pkg['current']['version'],
              latest: pkg['latest']['version'],
              resolvable: pkg['resolvable']?['version'],
            ),
          );
        }
      }

      return upgrades;
    } catch (e) {
      debugPrint('Error checking Flutter dependencies: $e');
      return [];
    }
  }

  Future<List<DependencyInfo>> checkAndroidDependencies() async {
    final gradlePath = path.join(projectRoot, 'build.gradle');
    final file = File(gradlePath);

    if (!file.existsSync()) return [];

    final content = await file.readAsString();
    final regex = RegExp(r'''implementation\s*\(?\s*['"]([^:'"]+):([^:'"]+):([^'"]+)['"]\s*\)?''');
    final matches = regex.allMatches(content);

    final deps = matches
        .map((m) => {'group': m.group(1)!, 'name': m.group(2)!, 'version': m.group(3)!})
        .toList();

    final results = <DependencyInfo>[];

    for (final dep in deps) {
      final query =
          'https://search.maven.org/solrsearch/select?q=g:${dep['group']}+AND+a:${dep['name']}&rows=1&wt=json';

      try {
        final response = await http.get(Uri.parse(query));
        final data = jsonDecode(response.body);
        final latest = data['response']['docs'][0]?['latestVersion'];

        if (latest != null && latest != dep['version']) {
          results.add(
            DependencyInfo(
              name: '${dep['group']}:${dep['name']}',
              current: dep['version']!,
              latest: latest,
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to fetch ${dep['name']}: $e');
      }
    }

    return results;
  }

  Future<List<DependencyInfo>> checkiOSDependencies() async {
    try {
      final result = await Process.run('pod', [
        'outdated',
        '--no-repo-update',
      ], workingDirectory: projectRoot);

      if (result.exitCode != 0) return [];

      final lines = (result.stdout as String).split('\n').where((l) => l.contains('->')).toList();

      final upgrades = <DependencyInfo>[];
      final regex = RegExp(r'(\S+)\s+(\d+\S+)\s+->\s+(\d+\S+)');

      for (final line in lines) {
        final match = regex.firstMatch(line);
        if (match != null) {
          upgrades.add(
            DependencyInfo(
              name: match.group(1)!,
              current: match.group(2)!,
              latest: match.group(3)!,
            ),
          );
        }
      }

      return upgrades;
    } catch (e) {
      return [];
    }
  }
}
