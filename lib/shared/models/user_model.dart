class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.profilePhoto,
    this.isVerified = false,
    this.description,
    this.githubUrl,
    this.linkedinUrl,
    this.twitterUrl,
    this.profilePreferences,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String name;
  final String? profilePhoto;
  final bool isVerified;
  final String? description;
  final String? githubUrl;
  final String? linkedinUrl;
  final String? twitterUrl;
  final ProfilePreferences? profilePreferences;
  final String? createdAt;
  final String? updatedAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profilePhoto: json['profilePhoto'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      description: json['description'] as String?,
      githubUrl: json['github_url'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
      twitterUrl: json['twitter_url'] as String?,
      profilePreferences: json['profile_preferences'] != null
          ? ProfilePreferences.fromJson(json['profile_preferences'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        if (description != null) 'description': description,
        if (githubUrl != null) 'github_url': githubUrl,
        if (linkedinUrl != null) 'linkedin_url': linkedinUrl,
        if (twitterUrl != null) 'twitter_url': twitterUrl,
        if (profilePreferences != null) 'profile_preferences': profilePreferences!.toJson(),
      };

  UserModel copyWith({
    String? name,
    String? profilePhoto,
    String? description,
    String? githubUrl,
    String? linkedinUrl,
    String? twitterUrl,
    ProfilePreferences? profilePreferences,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isVerified: isVerified,
      description: description ?? this.description,
      githubUrl: githubUrl ?? this.githubUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,
      profilePreferences: profilePreferences ?? this.profilePreferences,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ProfilePreferences {
  ProfilePreferences({
    this.hiddenProjectNames = const [],
    this.projectOrder = const [],
    this.hiddenSkillNames = const [],
    this.hiddenAppNames = const [],
    this.hiddenLanguageNames = const [],
  });

  final List<String> hiddenProjectNames;
  final List<String> projectOrder;
  final List<String> hiddenSkillNames;
  final List<String> hiddenAppNames;
  final List<String> hiddenLanguageNames;

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) {
    return ProfilePreferences(
      hiddenProjectNames: _toStringList(json['hidden_project_names']),
      projectOrder: _toStringList(json['project_order']),
      hiddenSkillNames: _toStringList(json['hidden_skill_names']),
      hiddenAppNames: _toStringList(json['hidden_app_names']),
      hiddenLanguageNames: _toStringList(json['hidden_language_names']),
    );
  }

  Map<String, dynamic> toJson() => {
        'hidden_project_names': hiddenProjectNames,
        'project_order': projectOrder,
        'hidden_skill_names': hiddenSkillNames,
        'hidden_app_names': hiddenAppNames,
        'hidden_language_names': hiddenLanguageNames,
      };

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
  }
}
