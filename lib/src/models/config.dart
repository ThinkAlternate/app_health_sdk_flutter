class GitHubConfig {
  final String token;
  final String owner;
  final String repo;

  GitHubConfig({required this.token, required this.owner, required this.repo});

  factory GitHubConfig.fromJson(Map<String, dynamic> json) {
    return GitHubConfig(
      token: json['token'] as String,
      owner: json['owner'] as String,
      repo: json['repo'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'owner': owner, 'repo': repo};
  }
}

class FirebaseConfig {
  final Map<String, dynamic> credentials;
  final String projectId;
  final String propertyId;

  FirebaseConfig({required this.credentials, required this.projectId, required this.propertyId});

  factory FirebaseConfig.fromJson(Map<String, dynamic> json) {
    return FirebaseConfig(
      credentials: json['credentials'] as Map<String, dynamic>,
      projectId: json['projectId'] as String,
      propertyId: json['propertyId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'credentials': credentials, 'projectId': projectId, 'propertyId': propertyId};
  }
}

class PlayStoreConfig {
  final Map<String, dynamic> serviceAccountKey;
  final String packageName;

  PlayStoreConfig({required this.serviceAccountKey, required this.packageName});

  factory PlayStoreConfig.fromJson(Map<String, dynamic> json) {
    return PlayStoreConfig(
      serviceAccountKey: json['serviceAccountKey'] as Map<String, dynamic>,
      packageName: json['packageName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'serviceAccountKey': serviceAccountKey, 'packageName': packageName};
  }
}

class AppHealthConfig {
  final String projectName;
  final String? packageName;
  final GitHubConfig? github;
  final FirebaseConfig? firebase;
  final PlayStoreConfig? playStore;

  AppHealthConfig({
    required this.projectName,
    this.packageName,
    this.github,
    this.firebase,
    this.playStore,
  });

  factory AppHealthConfig.fromJson(Map<String, dynamic> json) {
    return AppHealthConfig(
      projectName: json['name'] as String,
      packageName: json['packageName'] as String? ?? '',
      github: json['github'] != null
          ? GitHubConfig.fromJson(json['github'] as Map<String, dynamic>)
          : null,
      firebase: json['firebase'] != null
          ? FirebaseConfig.fromJson(json['firebase'] as Map<String, dynamic>)
          : null,
      playStore: json['playStore'] != null
          ? PlayStoreConfig.fromJson(json['playStore'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectName': projectName,
      'packageName': packageName,
      'github': github?.toJson(),
      'firebase': firebase?.toJson(),
      'playStore': playStore?.toJson(),
    };
  }
}
