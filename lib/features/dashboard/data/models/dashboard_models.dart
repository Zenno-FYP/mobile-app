// Performance Metrics
class MetricValue {
  MetricValue({required this.value, required this.changePercent});
  final double value;
  final double changePercent;

  factory MetricValue.fromJson(Map<String, dynamic> json) => MetricValue(
        value: (json['value'] as num?)?.toDouble() ?? 0,
        changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0,
      );
}

class PerformanceSummary {
  PerformanceSummary({
    required this.avgTypingIntensity,
    required this.avgMouseClickRate,
    required this.avgCorrections,
    required this.dailyActiveAverage,
  });
  final MetricValue avgTypingIntensity;
  final MetricValue avgMouseClickRate;
  final MetricValue avgCorrections;
  final MetricValue dailyActiveAverage;

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) => PerformanceSummary(
        avgTypingIntensity: MetricValue.fromJson(json['avg_typing_intensity'] as Map<String, dynamic>),
        avgMouseClickRate: MetricValue.fromJson(json['avg_mouse_click_rate'] as Map<String, dynamic>),
        avgCorrections: MetricValue.fromJson(json['avg_corrections'] as Map<String, dynamic>),
        dailyActiveAverage: MetricValue.fromJson(json['daily_active_average'] as Map<String, dynamic>),
      );
}

class UsageTrendBar {
  UsageTrendBar({
    required this.date,
    required this.dayName,
    required this.flowHours,
    required this.debuggingHours,
    required this.researchHours,
    required this.communicationHours,
    required this.distractedHours,
  });
  final String date;
  final String dayName;
  final double flowHours;
  final double debuggingHours;
  final double researchHours;
  final double communicationHours;
  final double distractedHours;

  factory UsageTrendBar.fromJson(Map<String, dynamic> json) => UsageTrendBar(
        date: json['date'] as String? ?? '',
        dayName: json['day_name'] as String? ?? '',
        flowHours: (json['flow_hours'] as num?)?.toDouble() ?? 0,
        debuggingHours: (json['debugging_hours'] as num?)?.toDouble() ?? 0,
        researchHours: (json['research_hours'] as num?)?.toDouble() ?? 0,
        communicationHours: (json['communication_hours'] as num?)?.toDouble() ?? 0,
        distractedHours: (json['distracted_hours'] as num?)?.toDouble() ?? 0,
      );
}

class PerformanceMetricsResponse {
  PerformanceMetricsResponse({
    required this.period,
    required this.performanceSummary,
    required this.usageTrendGraph,
  });
  final String period;
  final PerformanceSummary performanceSummary;
  final List<UsageTrendBar> usageTrendGraph;

  factory PerformanceMetricsResponse.fromJson(Map<String, dynamic> json) {
    return PerformanceMetricsResponse(
      period: json['period'] as String? ?? '',
      performanceSummary: PerformanceSummary.fromJson(json['performance_summary'] as Map<String, dynamic>),
      usageTrendGraph: (json['usage_trend_graph'] as List?)
              ?.map((e) => UsageTrendBar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Performance Metrics Detail
class DailyBehaviorMetrics {
  DailyBehaviorMetrics({
    required this.date,
    required this.dayName,
    required this.typingIntensityKpm,
    required this.mouseClickRateCpm,
    required this.correctionRatePercent,
    required this.activeHours,
    required this.idleHours,
  });
  final String date, dayName;
  final double typingIntensityKpm, mouseClickRateCpm, correctionRatePercent, activeHours, idleHours;

  factory DailyBehaviorMetrics.fromJson(Map<String, dynamic> json) => DailyBehaviorMetrics(
        date: json['date'] as String? ?? '',
        dayName: json['day_name'] as String? ?? '',
        typingIntensityKpm: (json['typing_intensity_kpm'] as num?)?.toDouble() ?? 0,
        mouseClickRateCpm: (json['mouse_click_rate_cpm'] as num?)?.toDouble() ?? 0,
        correctionRatePercent: (json['correction_rate_percent'] as num?)?.toDouble() ?? 0,
        activeHours: (json['active_hours'] as num?)?.toDouble() ?? 0,
        idleHours: (json['idle_hours'] as num?)?.toDouble() ?? 0,
      );
}

class PerformanceMetricsDetailResponse {
  PerformanceMetricsDetailResponse({required this.period, required this.performanceSummary, required this.dailySeries});
  final String period;
  final PerformanceSummary performanceSummary;
  final List<DailyBehaviorMetrics> dailySeries;

  factory PerformanceMetricsDetailResponse.fromJson(Map<String, dynamic> json) {
    return PerformanceMetricsDetailResponse(
      period: json['period'] as String? ?? '',
      performanceSummary: PerformanceSummary.fromJson(json['performance_summary'] as Map<String, dynamic>),
      dailySeries: (json['daily_series'] as List?)?.map((e) => DailyBehaviorMetrics.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

// Tool Usage
class AppUsageItem {
  AppUsageItem({required this.name, required this.durationHours, required this.percentOfTotal, required this.changePercent});
  final String name;
  final double durationHours, percentOfTotal, changePercent;

  factory AppUsageItem.fromJson(Map<String, dynamic> json) => AppUsageItem(
        name: json['name'] as String? ?? '',
        durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0,
        percentOfTotal: (json['percent_of_total'] as num?)?.toDouble() ?? 0,
        changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0,
      );
}

class TopApps {
  TopApps({required this.totalUsageHours, required this.usageIncreasePercent, required this.apps});
  final double totalUsageHours, usageIncreasePercent;
  final List<AppUsageItem> apps;

  factory TopApps.fromJson(Map<String, dynamic> json) => TopApps(
        totalUsageHours: (json['total_usage_hours'] as num?)?.toDouble() ?? 0,
        usageIncreasePercent: (json['usage_increase_from_yesterday_percent'] as num?)?.toDouble() ?? 0,
        apps: (json['apps'] as List?)?.map((e) => AppUsageItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class LanguageItem {
  LanguageItem({required this.name, required this.percent, required this.loc, required this.files});
  final String name;
  final double percent;
  final int loc, files;

  factory LanguageItem.fromJson(Map<String, dynamic> json) => LanguageItem(
        name: json['name'] as String? ?? '',
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
        loc: (json['loc'] as num?)?.toInt() ?? 0,
        files: (json['files'] as num?)?.toInt() ?? 0,
      );
}

class LanguageSummary {
  LanguageSummary({required this.totalLinesOfCode, required this.totalFiles, required this.totalLanguagesUsed});
  final int totalLinesOfCode, totalFiles, totalLanguagesUsed;

  factory LanguageSummary.fromJson(Map<String, dynamic> json) => LanguageSummary(
        totalLinesOfCode: (json['total_lines_of_code'] as num?)?.toInt() ?? 0,
        totalFiles: (json['total_files'] as num?)?.toInt() ?? 0,
        totalLanguagesUsed: (json['total_languages_used'] as num?)?.toInt() ?? 0,
      );
}

class LanguageDistribution {
  LanguageDistribution({required this.summary, required this.languages});
  final LanguageSummary summary;
  final List<LanguageItem> languages;

  factory LanguageDistribution.fromJson(Map<String, dynamic> json) => LanguageDistribution(
        summary: LanguageSummary.fromJson(json['summary'] as Map<String, dynamic>),
        languages: (json['languages'] as List?)?.map((e) => LanguageItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class ToolUsageResponse {
  ToolUsageResponse({required this.period, required this.topApps, required this.languageDistribution});
  final String period;
  final TopApps topApps;
  final LanguageDistribution languageDistribution;

  factory ToolUsageResponse.fromJson(Map<String, dynamic> json) => ToolUsageResponse(
        period: json['period'] as String? ?? '',
        topApps: TopApps.fromJson(json['top_apps'] as Map<String, dynamic>),
        languageDistribution: LanguageDistribution.fromJson(json['language_distribution'] as Map<String, dynamic>),
      );
}

// Tool Usage Detail
class ToolUsageDetailResponse {
  ToolUsageDetailResponse({
    required this.period,
    required this.uniqueAppsCount,
    required this.categoryBreakdown,
    required this.dailyAppUsage,
    required this.topApps,
    required this.languageDistribution,
  });
  final String period;
  final int uniqueAppsCount;
  final List<AppCategoryUsage> categoryBreakdown;
  final List<DailyAppUsage> dailyAppUsage;
  final TopApps topApps;
  final LanguageDistribution languageDistribution;

  factory ToolUsageDetailResponse.fromJson(Map<String, dynamic> json) => ToolUsageDetailResponse(
        period: json['period'] as String? ?? '',
        uniqueAppsCount: (json['unique_apps_count'] as num?)?.toInt() ?? 0,
        categoryBreakdown: (json['category_breakdown'] as List?)?.map((e) => AppCategoryUsage.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        dailyAppUsage: (json['daily_app_usage'] as List?)?.map((e) => DailyAppUsage.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        topApps: TopApps.fromJson(json['top_apps'] as Map<String, dynamic>),
        languageDistribution: LanguageDistribution.fromJson(json['language_distribution'] as Map<String, dynamic>),
      );
}

class AppCategoryUsage {
  AppCategoryUsage({required this.category, required this.hours, required this.percentOfTotal});
  final String category;
  final double hours, percentOfTotal;

  factory AppCategoryUsage.fromJson(Map<String, dynamic> json) => AppCategoryUsage(
        category: json['category'] as String? ?? '',
        hours: (json['hours'] as num?)?.toDouble() ?? 0,
        percentOfTotal: (json['percent_of_total'] as num?)?.toDouble() ?? 0,
      );
}

class DailyAppUsage {
  DailyAppUsage({required this.date, required this.dayName, required this.totalHours});
  final String date, dayName;
  final double totalHours;

  factory DailyAppUsage.fromJson(Map<String, dynamic> json) => DailyAppUsage(
        date: json['date'] as String? ?? '',
        dayName: json['day_name'] as String? ?? '',
        totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0,
      );
}

// Project Insights
class SkillDto {
  SkillDto({required this.name, required this.percent});
  final String name;
  final double percent;

  factory SkillDto.fromJson(Map<String, dynamic> json) => SkillDto(
        name: json['name'] as String? ?? '',
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
      );
}

class ProjectItem {
  ProjectItem({required this.name, this.displayName, this.lastActive});
  final String name;
  final String? displayName, lastActive;

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
        name: json['name'] as String? ?? '',
        displayName: json['display_name'] as String?,
        lastActive: json['last_active'] as String?,
      );
}

class ProjectInsightsResponse {
  ProjectInsightsResponse({required this.strongestSkills, required this.currentProjects});
  final List<SkillDto> strongestSkills;
  final List<ProjectItem> currentProjects;

  factory ProjectInsightsResponse.fromJson(Map<String, dynamic> json) => ProjectInsightsResponse(
        strongestSkills: (json['strongest_skills'] as List?)?.map((e) => SkillDto.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        currentProjects: (json['current_projects'] as List?)?.map((e) => ProjectItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// Skills & Projects Detail
class SkillsProjectsSummary {
  SkillsProjectsSummary({required this.totalProjects, required this.totalAppTimeHours, required this.uniqueSkillsCount, required this.totalLinesOfCode});
  final int totalProjects, uniqueSkillsCount, totalLinesOfCode;
  final double totalAppTimeHours;

  factory SkillsProjectsSummary.fromJson(Map<String, dynamic> json) => SkillsProjectsSummary(
        totalProjects: (json['total_projects'] as num?)?.toInt() ?? 0,
        totalAppTimeHours: (json['total_app_time_hours'] as num?)?.toDouble() ?? 0,
        uniqueSkillsCount: (json['unique_skills_count'] as num?)?.toInt() ?? 0,
        totalLinesOfCode: (json['total_lines_of_code'] as num?)?.toInt() ?? 0,
      );
}

class SkillTime {
  SkillTime({required this.name, required this.durationHours, required this.percentOfTotal});
  final String name;
  final double durationHours, percentOfTotal;

  factory SkillTime.fromJson(Map<String, dynamic> json) => SkillTime(
        name: json['name'] as String? ?? '',
        durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0,
        percentOfTotal: (json['percent_of_total'] as num?)?.toDouble() ?? 0,
      );
}

class ProjectOverviewItem {
  ProjectOverviewItem({required this.name, this.displayName, required this.description, this.lastActive, this.firstSeen, required this.totalLines, required this.totalFiles, required this.topLanguages, required this.skills, required this.appTimeHours});
  final String name, description;
  final String? displayName, lastActive, firstSeen;
  final int totalLines, totalFiles;
  final List<ProjectLanguageLine> topLanguages;
  final List<ProjectSkillTime> skills;
  final double appTimeHours;

  factory ProjectOverviewItem.fromJson(Map<String, dynamic> json) => ProjectOverviewItem(
        name: json['name'] as String? ?? '',
        displayName: json['display_name'] as String?,
        description: json['description'] as String? ?? '',
        lastActive: json['last_active'] as String?,
        firstSeen: json['first_seen'] as String?,
        totalLines: (json['total_lines'] as num?)?.toInt() ?? 0,
        totalFiles: (json['total_files'] as num?)?.toInt() ?? 0,
        topLanguages: (json['top_languages'] as List?)?.map((e) => ProjectLanguageLine.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        skills: (json['skills'] as List?)?.map((e) => ProjectSkillTime.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        appTimeHours: (json['app_time_hours'] as num?)?.toDouble() ?? 0,
      );
}

class ProjectLanguageLine {
  ProjectLanguageLine({required this.name, required this.lines});
  final String name;
  final int lines;

  factory ProjectLanguageLine.fromJson(Map<String, dynamic> json) => ProjectLanguageLine(
        name: json['name'] as String? ?? '',
        lines: (json['lines'] as num?)?.toInt() ?? 0,
      );
}

class ProjectSkillTime {
  ProjectSkillTime({required this.name, required this.durationSec, required this.durationHours});
  final String name;
  final double durationSec, durationHours;

  factory ProjectSkillTime.fromJson(Map<String, dynamic> json) => ProjectSkillTime(
        name: json['name'] as String? ?? '',
        durationSec: (json['duration_sec'] as num?)?.toDouble() ?? 0,
        durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0,
      );
}

class SkillsProjectsDetailResponse {
  SkillsProjectsDetailResponse({required this.summary, required this.skills, required this.projects});
  final SkillsProjectsSummary summary;
  final List<SkillTime> skills;
  final List<ProjectOverviewItem> projects;

  factory SkillsProjectsDetailResponse.fromJson(Map<String, dynamic> json) => SkillsProjectsDetailResponse(
        summary: SkillsProjectsSummary.fromJson(json['summary'] as Map<String, dynamic>),
        skills: (json['skills'] as List?)?.map((e) => SkillTime.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        projects: (json['projects'] as List?)?.map((e) => ProjectOverviewItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// Profile Page
class ProfileProjectInsight {
  ProfileProjectInsight({required this.kind, this.flowFocusPercent, this.label, this.percent});
  final String kind;
  final double? flowFocusPercent, percent;
  final String? label;

  factory ProfileProjectInsight.fromJson(Map<String, dynamic> json) => ProfileProjectInsight(
        kind: json['kind'] as String? ?? 'none',
        flowFocusPercent: (json['flow_focus_percent'] as num?)?.toDouble(),
        label: json['label'] as String?,
        percent: (json['percent'] as num?)?.toDouble(),
      );
}

class ProfileProjectCard {
  ProfileProjectCard({required this.projectName, this.displayName, required this.description, this.lastActive, required this.appTimeHours, required this.languages, required this.topApps, required this.topSkills, required this.insight});
  final String projectName, description;
  final String? displayName, lastActive;
  final double appTimeHours;
  final List<ProfileProjectLanguageShare> languages;
  final List<ProfileProjectAppRow> topApps;
  final List<ProfileProjectSkillRow> topSkills;
  final ProfileProjectInsight insight;

  factory ProfileProjectCard.fromJson(Map<String, dynamic> json) => ProfileProjectCard(
        projectName: json['project_name'] as String? ?? '',
        displayName: json['display_name'] as String?,
        description: json['description'] as String? ?? '',
        lastActive: json['last_active'] as String?,
        appTimeHours: (json['app_time_hours'] as num?)?.toDouble() ?? 0,
        languages: (json['languages'] as List?)?.map((e) => ProfileProjectLanguageShare.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        topApps: (json['top_apps'] as List?)?.map((e) => ProfileProjectAppRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        topSkills: (json['top_skills'] as List?)?.map((e) => ProfileProjectSkillRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        insight: ProfileProjectInsight.fromJson(json['insight'] as Map<String, dynamic>? ?? {}),
      );
}

class ProfileProjectLanguageShare {
  ProfileProjectLanguageShare({required this.name, required this.percent});
  final String name;
  final double percent;
  factory ProfileProjectLanguageShare.fromJson(Map<String, dynamic> json) => ProfileProjectLanguageShare(
        name: json['name'] as String? ?? '', percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProfileProjectAppRow {
  ProfileProjectAppRow({required this.name, required this.durationHours, required this.percent});
  final String name;
  final double durationHours, percent;
  factory ProfileProjectAppRow.fromJson(Map<String, dynamic> json) => ProfileProjectAppRow(
        name: json['name'] as String? ?? '', durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0, percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProfileProjectSkillRow {
  ProfileProjectSkillRow({required this.name, required this.durationHours, required this.percent});
  final String name;
  final double durationHours, percent;
  factory ProfileProjectSkillRow.fromJson(Map<String, dynamic> json) => ProfileProjectSkillRow(
        name: json['name'] as String? ?? '', durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0, percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProfileGlobalRow {
  ProfileGlobalRow({required this.name, required this.durationHours, required this.percent});
  final String name;
  final double durationHours, percent;
  factory ProfileGlobalRow.fromJson(Map<String, dynamic> json) => ProfileGlobalRow(
        name: json['name'] as String? ?? '', durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0, percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProfileGlobalLanguageRow {
  ProfileGlobalLanguageRow({required this.name, required this.lines, required this.percent});
  final String name;
  final int lines;
  final double percent;
  factory ProfileGlobalLanguageRow.fromJson(Map<String, dynamic> json) => ProfileGlobalLanguageRow(
        name: json['name'] as String? ?? '', lines: (json['lines'] as num?)?.toInt() ?? 0, percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProfilePageResponse {
  ProfilePageResponse({required this.streakDays, required this.totalAppTimeHours, required this.totalProjects, this.globalFlowFocusPercent, required this.topSkills, required this.topApps, required this.topLanguages, required this.projects});
  final int streakDays, totalProjects;
  final double totalAppTimeHours;
  final double? globalFlowFocusPercent;
  final List<ProfileGlobalRow> topSkills, topApps;
  final List<ProfileGlobalLanguageRow> topLanguages;
  final List<ProfileProjectCard> projects;

  factory ProfilePageResponse.fromJson(Map<String, dynamic> json) => ProfilePageResponse(
        streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
        totalAppTimeHours: (json['total_app_time_hours'] as num?)?.toDouble() ?? 0,
        totalProjects: (json['total_projects'] as num?)?.toInt() ?? 0,
        globalFlowFocusPercent: (json['global_flow_focus_percent'] as num?)?.toDouble(),
        topSkills: (json['top_skills'] as List?)?.map((e) => ProfileGlobalRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        topApps: (json['top_apps'] as List?)?.map((e) => ProfileGlobalRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        topLanguages: (json['top_languages'] as List?)?.map((e) => ProfileGlobalLanguageRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        projects: (json['projects'] as List?)?.map((e) => ProfileProjectCard.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// Public Profile
class PublicProfileUser {
  PublicProfileUser({required this.name, this.profilePhoto, required this.description, this.githubUrl, this.linkedinUrl, this.twitterUrl, this.createdAt});
  final String name, description;
  final String? profilePhoto, githubUrl, linkedinUrl, twitterUrl, createdAt;

  factory PublicProfileUser.fromJson(Map<String, dynamic> json) => PublicProfileUser(
        name: json['name'] as String? ?? '',
        profilePhoto: json['profilePhoto'] as String?,
        description: json['description'] as String? ?? '',
        githubUrl: json['github_url'] as String?,
        linkedinUrl: json['linkedin_url'] as String?,
        twitterUrl: json['twitter_url'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}

class PublicProfileResponse {
  PublicProfileResponse({required this.user, required this.profile});
  final PublicProfileUser user;
  final ProfilePageResponse profile;

  factory PublicProfileResponse.fromJson(Map<String, dynamic> json) => PublicProfileResponse(
        user: PublicProfileUser.fromJson(json['user'] as Map<String, dynamic>),
        profile: ProfilePageResponse.fromJson(json['profile'] as Map<String, dynamic>),
      );
}

// Peers Search
class PeerCard {
  PeerCard({required this.userId, required this.name, this.profilePhotoUrl, required this.bio, required this.topSkills, required this.topProjects, required this.topApps});
  final String userId, name, bio;
  final String? profilePhotoUrl;
  final List<String> topSkills, topProjects, topApps;

  factory PeerCard.fromJson(Map<String, dynamic> json) => PeerCard(
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        profilePhotoUrl: json['profile_photo_url'] as String?,
        bio: json['bio'] as String? ?? '',
        topSkills: _strList(json['top_skills']),
        topProjects: _strList(json['top_projects']),
        topApps: _strList(json['top_apps']),
      );

  static List<String> _strList(dynamic v) => v is List ? v.cast<String>() : [];
}

class PeersSearchResponse {
  PeersSearchResponse({required this.peers});
  final List<PeerCard> peers;

  factory PeersSearchResponse.fromJson(Map<String, dynamic> json) => PeersSearchResponse(
        peers: (json['peers'] as List?)?.map((e) => PeerCard.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

// Project Detail
class ProjectDetailResponse {
  ProjectDetailResponse({required this.projectName, this.displayName, required this.description, this.firstSeen, this.lastActive, required this.appTimeHours, required this.totalLines, required this.totalFiles, required this.languages, required this.topApps, required this.languagesByActiveTime, required this.contextBreakdown, required this.behavior, required this.skills});
  final String projectName, description;
  final String? displayName, firstSeen, lastActive;
  final double appTimeHours;
  final int totalLines, totalFiles;
  final List<ProjectLanguageShare> languages;
  final List<ProjectNamedHoursRow> topApps, languagesByActiveTime;
  final ProjectContextBreakdown contextBreakdown;
  final ProjectBehaviorSummary behavior;
  final List<ProjectSkillRow> skills;

  factory ProjectDetailResponse.fromJson(Map<String, dynamic> json) => ProjectDetailResponse(
        projectName: json['project_name'] as String? ?? '',
        displayName: json['display_name'] as String?,
        description: json['description'] as String? ?? '',
        firstSeen: json['first_seen'] as String?,
        lastActive: json['last_active'] as String?,
        appTimeHours: (json['app_time_hours'] as num?)?.toDouble() ?? 0,
        totalLines: (json['total_lines'] as num?)?.toInt() ?? 0,
        totalFiles: (json['total_files'] as num?)?.toInt() ?? 0,
        languages: (json['languages'] as List?)?.map((e) => ProjectLanguageShare.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        topApps: (json['top_apps'] as List?)?.map((e) => ProjectNamedHoursRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        languagesByActiveTime: (json['languages_by_active_time'] as List?)?.map((e) => ProjectNamedHoursRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        contextBreakdown: ProjectContextBreakdown.fromJson(json['context_breakdown'] as Map<String, dynamic>? ?? {}),
        behavior: ProjectBehaviorSummary.fromJson(json['behavior'] as Map<String, dynamic>? ?? {}),
        skills: (json['skills'] as List?)?.map((e) => ProjectSkillRow.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class ProjectLanguageShare {
  ProjectLanguageShare({required this.name, required this.lines, required this.percent});
  final String name;
  final int lines;
  final double percent;
  factory ProjectLanguageShare.fromJson(Map<String, dynamic> json) => ProjectLanguageShare(
        name: json['name'] as String? ?? '', lines: (json['lines'] as num?)?.toInt() ?? 0, percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProjectNamedHoursRow {
  ProjectNamedHoursRow({required this.name, required this.durationHours, required this.percent});
  final String name;
  final double durationHours, percent;
  factory ProjectNamedHoursRow.fromJson(Map<String, dynamic> json) => ProjectNamedHoursRow(
        name: json['name'] as String? ?? '', durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0, percent: (json['percent'] as num?)?.toDouble() ?? 0);
}

class ProjectContextBreakdown {
  ProjectContextBreakdown({required this.flowHours, required this.debuggingHours, required this.researchHours, required this.communicationHours, required this.distractedHours, required this.otherHours});
  final double flowHours, debuggingHours, researchHours, communicationHours, distractedHours, otherHours;
  factory ProjectContextBreakdown.fromJson(Map<String, dynamic> json) => ProjectContextBreakdown(
        flowHours: (json['flow_hours'] as num?)?.toDouble() ?? 0, debuggingHours: (json['debugging_hours'] as num?)?.toDouble() ?? 0, researchHours: (json['research_hours'] as num?)?.toDouble() ?? 0, communicationHours: (json['communication_hours'] as num?)?.toDouble() ?? 0, distractedHours: (json['distracted_hours'] as num?)?.toDouble() ?? 0, otherHours: (json['other_hours'] as num?)?.toDouble() ?? 0);
}

class ProjectBehaviorSummary {
  ProjectBehaviorSummary({required this.avgTypingKpm, required this.avgMouseCpm, required this.totalIdleHours});
  final double avgTypingKpm, avgMouseCpm, totalIdleHours;
  factory ProjectBehaviorSummary.fromJson(Map<String, dynamic> json) => ProjectBehaviorSummary(
        avgTypingKpm: (json['avg_typing_kpm'] as num?)?.toDouble() ?? 0, avgMouseCpm: (json['avg_mouse_cpm'] as num?)?.toDouble() ?? 0, totalIdleHours: (json['total_idle_hours'] as num?)?.toDouble() ?? 0);
}

class ProjectSkillRow {
  ProjectSkillRow({required this.name, required this.durationSec, required this.durationHours});
  final String name;
  final double durationSec, durationHours;
  factory ProjectSkillRow.fromJson(Map<String, dynamic> json) => ProjectSkillRow(
        name: json['name'] as String? ?? '', durationSec: (json['duration_sec'] as num?)?.toDouble() ?? 0, durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 0);
}
