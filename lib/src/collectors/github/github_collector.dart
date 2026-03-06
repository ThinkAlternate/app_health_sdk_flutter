import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GitHubCollector {
  final String token;
  late final http.Client _client;

  GitHubCollector(this.token) {
    _client = http.Client();
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github.v3+json',
  };

  Future<List<dynamic>> getCommits(String owner, String repo) async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$owner/$repo/commits?per_page=100'),
      headers: _headers,
    );
    return jsonDecode(res.body) as List;
  }

  Future<List<dynamic>> getBranches(String owner, String repo) async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$owner/$repo/branches'),
      headers: _headers,
    );
    return jsonDecode(res.body) as List;
  }

  Future<Map<String, dynamic>> getLanguages(String owner, String repo) async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$owner/$repo/languages'),
      headers: _headers,
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getCommitsForAllBranches(String owner, String repo) async {
    final branches = await getBranches(owner, repo);
    final allCommits = <Map<String, dynamic>>[];

    for (final branch in branches) {
      final branchName = branch['name'];
      final res = await _client.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/commits?sha=$branchName&per_page=100'),
        headers: _headers,
      );

      final commits = jsonDecode(res.body) as List;
      for (final commit in commits) {
        allCommits.add({...commit as Map<String, dynamic>, 'branch': branch});
      }
    }

    return allCommits;
  }

  Future<List<dynamic>> getReleases(String owner, String repo) async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases'),
      headers: _headers,
    );
    return jsonDecode(res.body) as List;
  }

  Future<List<dynamic>> getWorkflows(String owner, String repo) async {
    try {
      final res = await _client.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/actions/workflows'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      return data['workflows'] as List;
    } catch (e) {
      debugPrint('⚠️ No workflows found for $owner/$repo');
      return [];
    }
  }

  List<String> getUniqueContributors(List<Map<String, dynamic>> commits) {
    final contributors = <String>{};
    for (final commit in commits) {
      final author = commit['author']?['login'] ?? commit['commit']?['author']?['name'];
      if (author != null) contributors.add(author);
    }
    return contributors.toList();
  }

  bool isLastWeek(String dateStr) {
    final date = DateTime.parse(dateStr);
    final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    return date.isAfter(oneWeekAgo) || date.isAtSameMomentAs(oneWeekAgo);
  }

  double getDuration(Map<String, dynamic> run) {
    final start = DateTime.parse(run['created_at']);
    final end = DateTime.parse(run['updated_at']);
    return end.difference(start).inSeconds.toDouble();
  }

  Map<String, int> categorizeFailures(List<Map<String, dynamic>> failures) {
    final reasons = <String, int>{};
    for (final fail in failures) {
      final reason = fail['name'] ?? 'unknown';
      reasons[reason] = (reasons[reason] ?? 0) + 1;
    }
    return reasons;
  }

  Future<Map<String, dynamic>> analyzeCICD(
    List<dynamic> workflows,
    String owner,
    String repo,
  ) async {
    if (workflows.isEmpty) {
      return {'successRate': 0.0, 'averageDuration': 0.0, 'failureReasons': {}};
    }

    final runs = <Map<String, dynamic>>[];

    for (final workflow in workflows) {
      final res = await _client.get(
        Uri.parse(
          'https://api.github.com/repos/$owner/$repo/actions/workflows/${workflow['id']}/runs',
        ),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      runs.addAll((data['workflow_runs'] as List).cast<Map<String, dynamic>>());
    }

    if (runs.isEmpty) {
      return {'successRate': 0.0, 'averageDuration': 0.0, 'failureReasons': {}};
    }

    final successCount = runs.where((r) => r['conclusion'] == 'success').length;
    final avgDuration = runs.fold<double>(0, (sum, r) => sum + getDuration(r)) / runs.length;
    final failures = runs.where((r) => r['conclusion'] == 'failure').toList();

    return {
      'successRate': successCount / runs.length,
      'averageDuration': avgDuration,
      'failureReasons': categorizeFailures(failures),
    };
  }

  Future<Map<String, dynamic>> collectRepoData(String owner, String repo) async {
    final results = await Future.wait([
      getCommitsForAllBranches(owner, repo),
      getBranches(owner, repo),
      getReleases(owner, repo),
      getWorkflows(owner, repo),
    ]);

    final commits = results[0] as List<Map<String, dynamic>>;
    final branches = results[1];
    final releases = results[2];
    final workflows = results[3];

    return {
      'repo': '$owner/$repo',
      'commits': {
        'total': commits.length,
        'lastWeek': commits.where((c) => isLastWeek(c['commit']['author']['date'])).toList(),
        'contributors': getUniqueContributors(commits),
        'commits_data': commits,
      },
      'branches': branches,
      'releases': releases.map((r) {
        final assets = r['assets'] as List;
        return {
          'version': r['tag_name'],
          'date': r['published_at'],
          'downloads': assets.fold<int>(0, (sum, asset) => sum + (asset['download_count'] as int)),
        };
      }).toList(),
      'cicd': await analyzeCICD(workflows, owner, repo),
    };
  }

  void dispose() {
    _client.close();
  }
}
