import '../../../core/network/api_client.dart';
import 'models/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<PerformanceMetricsResponse> getPerformanceMetrics({String period = 'current_week'}) async {
    final params = period != 'current_week' ? {'period': period} : null;
    final data = await _client.get('/dashboard/performance-metrics', queryParams: params);
    return PerformanceMetricsResponse.fromJson(data);
  }

  Future<PerformanceMetricsDetailResponse> getPerformanceMetricsDetail({String period = 'week'}) async {
    final data = await _client.get(
      '/dashboard/performance-metrics-detail',
      queryParams: {'period': period},
    );
    return PerformanceMetricsDetailResponse.fromJson(data);
  }

  Future<ToolUsageResponse> getToolUsage() async {
    final data = await _client.get('/dashboard/tool-usage');
    return ToolUsageResponse.fromJson(data);
  }

  Future<ToolUsageDetailResponse> getToolUsageDetail() async {
    final data = await _client.get('/dashboard/tool-usage-detail');
    return ToolUsageDetailResponse.fromJson(data);
  }

  Future<ProjectInsightsResponse> getProjectInsights() async {
    final data = await _client.get('/dashboard/project-insights');
    return ProjectInsightsResponse.fromJson(data);
  }

  Future<SkillsProjectsDetailResponse> getSkillsProjectsDetail() async {
    final data = await _client.get('/dashboard/skills-projects-detail');
    return SkillsProjectsDetailResponse.fromJson(data);
  }

  Future<ProfilePageResponse> getProfilePage() async {
    final data = await _client.get('/dashboard/profile-page');
    return ProfilePageResponse.fromJson(data);
  }

  Future<PublicProfileResponse> getPublicProfile(String userId) async {
    final data = await _client.get('/dashboard/users/$userId/public-profile');
    return PublicProfileResponse.fromJson(data);
  }

  Future<PeersSearchResponse> searchPeers(String query) async {
    final data = await _client.get('/dashboard/peers/search', queryParams: {'q': query});
    return PeersSearchResponse.fromJson(data);
  }

  Future<ProjectDetailResponse> getProjectDetail(String projectName) async {
    final data = await _client.get('/dashboard/projects/${Uri.encodeComponent(projectName)}');
    return ProjectDetailResponse.fromJson(data);
  }

  Future<void> updateProject(String projectName, Map<String, dynamic> body) async {
    await _client.patch('/dashboard/projects/${Uri.encodeComponent(projectName)}', data: body);
  }

  Future<void> deleteProject(String projectName) async {
    await _client.delete('/dashboard/projects/${Uri.encodeComponent(projectName)}');
  }
}
