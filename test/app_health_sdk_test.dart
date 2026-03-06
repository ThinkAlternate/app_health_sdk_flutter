import 'package:app_health_sdk/app_health_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppHealthConfig Tests', () {
    test('fromJson creates correct config object', () {
      final json = {
        'projectName': 'TestProject',
        'packageName': 'com.example.test',
        'github': {'token': 'gh_token', 'owner': 'owner', 'repo': 'repo'},
      };

      final config = AppHealthConfig.fromJson(json);

      expect(config.projectName, 'TestProject');
      expect(config.packageName, 'com.example.test');
      expect(config.github?.token, 'gh_token');
      expect(config.github?.owner, 'owner');
      expect(config.github?.repo, 'repo');
    });

    test('toJson creates correct map', () {
      final config = AppHealthConfig(
        projectName: 'TestProject',
        packageName: 'com.example.test',
        github: GitHubConfig(token: 'gh_token', owner: 'owner', repo: 'repo'),
      );

      final json = config.toJson();

      expect(json['projectName'], 'TestProject');
      expect(json['packageName'], 'com.example.test');
      expect(json['github']['token'], 'gh_token');
    });
  });
}
