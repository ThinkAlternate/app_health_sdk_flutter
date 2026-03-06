import 'package:app_health_sdk/src/dashboard/api/api_client.dart';

class ProjectService {
  final NextJSApiClient client;

  ProjectService(String baseUrl) : client = NextJSApiClient(baseUrl);

  Future<Map<String, dynamic>> createProject(String name, String type, double confidence) {
    return client.createProject(name, type, confidence);
  }

  Future<Map<String, dynamic>> uploadAppStoreData(
    String projectName,
    String projectType,
    Map<String, dynamic> appStoreData,
    Map<String, dynamic> appInfo,
  ) {
    return client.uploadAppStoreData({
      'projectName': projectName,
      'projectType': projectType,
      'projectData': appStoreData,
      'appInfo': appInfo,
    });
  }

  Future<Map<String, dynamic>> uploadPlayStoreData(
    String projectName,
    String projectType,
    Map<String, dynamic> playStoreData,
  ) {
    return client.uploadPlayStoreData({
      'projectName': projectName,
      'projectType': projectType,
      'projectData': playStoreData,
    });
  }

  Future<Map<String, dynamic>> uploadGitHubData(
    Map<String, dynamic> githubData,
    String projectName,
    String projectType,
    String repoName,
  ) {
    return client.uploadGitHubData({
      'data': githubData,
      'projectName': projectName,
      'projectType': projectType,
      'repoName': repoName,
    });
  }

  Future<Map<String, dynamic>> uploadDependencies(
    String projectName,
    String packageName,
    List<dynamic> upgrades,
  ) {
    return client.uploadDependencies({
      'projectName': projectName,
      'packageName': packageName,
      'upgrades': upgrades,
    });
  }

  Future<Map<String, dynamic>> uploadAnalytics(
    String projectName,
    String packageName,
    Map<String, dynamic> analytics,
  ) {
    return client.uploadAnalytics({
      'projectName': projectName,
      'packageName': packageName,
      'analytics': analytics,
    });
  }

  Future<Map<String, dynamic>> fetchConfig(String apiKey) {
    return client.fetchConfig(apiKey);
  }
}
