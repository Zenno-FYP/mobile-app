class AgentPreferences {
  AgentPreferences({
    this.workSchedule = 'standard',
    this.focusStyle = 'moderate',
    this.wellbeingGoal = 'focused',
    this.hasMeetings = false,
    this.nudgeEnabled = true,
    this.agentTone = 'friendly',
  });

  final String workSchedule;
  final String focusStyle;
  final String wellbeingGoal;
  final bool hasMeetings;
  final bool nudgeEnabled;
  final String agentTone;

  factory AgentPreferences.fromJson(Map<String, dynamic> json) => AgentPreferences(
        workSchedule: json['work_schedule'] as String? ?? 'standard',
        focusStyle: json['focus_style'] as String? ?? 'moderate',
        wellbeingGoal: json['wellbeing_goal'] as String? ?? 'focused',
        hasMeetings: json['has_meetings'] as bool? ?? false,
        nudgeEnabled: json['nudge_enabled'] as bool? ?? true,
        agentTone: json['agent_tone'] as String? ?? 'friendly',
      );

  AgentPreferences copyWith({
    String? workSchedule,
    String? focusStyle,
    String? wellbeingGoal,
    bool? hasMeetings,
    bool? nudgeEnabled,
    String? agentTone,
  }) => AgentPreferences(
        workSchedule: workSchedule ?? this.workSchedule,
        focusStyle: focusStyle ?? this.focusStyle,
        wellbeingGoal: wellbeingGoal ?? this.wellbeingGoal,
        hasMeetings: hasMeetings ?? this.hasMeetings,
        nudgeEnabled: nudgeEnabled ?? this.nudgeEnabled,
        agentTone: agentTone ?? this.agentTone,
      );
}

class NudgeStats {
  NudgeStats({this.totalNudges = 0, this.nudgesToday = 0, this.suppressedCount = 0});
  final int totalNudges, nudgesToday, suppressedCount;

  factory NudgeStats.fromJson(Map<String, dynamic> json) => NudgeStats(
        totalNudges: (json['total_nudges'] as num?)?.toInt() ?? 0,
        nudgesToday: (json['nudges_today'] as num?)?.toInt() ?? 0,
        suppressedCount: (json['suppressed_count'] as num?)?.toInt() ?? 0,
      );
}
