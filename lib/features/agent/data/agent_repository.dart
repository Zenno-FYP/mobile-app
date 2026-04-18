import '../../../core/network/api_client.dart';
import 'agent_models.dart';

class AgentRepository {
  AgentRepository(this._client);
  final ApiClient _client;

  Future<AgentPreferences> getPreferences() async {
    final data = await _client.get('/agent/preferences');
    return AgentPreferences.fromJson((data['data'] ?? data) as Map<String, dynamic>);
  }

  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    await _client.put('/agent/preferences', data: prefs);
  }

  Future<NudgeStats> getNudgeStats() async {
    final data = await _client.get('/agent/nudges/stats');
    return NudgeStats.fromJson((data['data'] ?? data) as Map<String, dynamic>);
  }
}
