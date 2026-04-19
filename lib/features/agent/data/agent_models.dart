/// Mirror of the backend's `agent_preferences` document. The
/// `notification_sound` toggle replaces the long-removed `has_meetings`
/// field; the website surfaces the same control on its Zenno Agent page.
class AgentPreferences {
  AgentPreferences({
    this.workSchedule = 'standard',
    this.focusStyle = 'moderate',
    this.wellbeingGoal = 'focused',
    this.notificationSound = false,
    this.nudgeEnabled = true,
    this.agentTone = 'friendly',
  });

  final String workSchedule;
  final String focusStyle;
  final String wellbeingGoal;
  final bool notificationSound;
  final bool nudgeEnabled;
  final String agentTone;

  factory AgentPreferences.fromJson(Map<String, dynamic> json) => AgentPreferences(
        workSchedule: json['work_schedule'] as String? ?? 'standard',
        focusStyle: json['focus_style'] as String? ?? 'moderate',
        wellbeingGoal: json['wellbeing_goal'] as String? ?? 'focused',
        notificationSound: json['notification_sound'] as bool? ?? false,
        nudgeEnabled: json['nudge_enabled'] as bool? ?? true,
        agentTone: json['agent_tone'] as String? ?? 'friendly',
      );

  AgentPreferences copyWith({
    String? workSchedule,
    String? focusStyle,
    String? wellbeingGoal,
    bool? notificationSound,
    bool? nudgeEnabled,
    String? agentTone,
  }) =>
      AgentPreferences(
        workSchedule: workSchedule ?? this.workSchedule,
        focusStyle: focusStyle ?? this.focusStyle,
        wellbeingGoal: wellbeingGoal ?? this.wellbeingGoal,
        notificationSound: notificationSound ?? this.notificationSound,
        nudgeEnabled: nudgeEnabled ?? this.nudgeEnabled,
        agentTone: agentTone ?? this.agentTone,
      );
}

/// Live nudge stats from `/agent/nudges/stats`. Field names match the
/// backend response exactly (`today_nudges`, `total_suppressed`, etc.) —
/// the previous mobile model used `nudges_today`/`suppressed_count` which
/// are not produced by the API and silently parsed as 0.
class NudgeStats {
  NudgeStats({
    this.totalNudges = 0,
    this.todayNudges = 0,
    this.thisWeekNudges = 0,
    this.totalSuppressed = 0,
    this.suppressedByReason = const {},
  });

  final int totalNudges;
  final int todayNudges;
  final int thisWeekNudges;
  final int totalSuppressed;
  final Map<String, int> suppressedByReason;

  factory NudgeStats.fromJson(Map<String, dynamic> json) {
    final raw = (json['suppressed_by_reason'] as Map?) ?? const {};
    final reasons = <String, int>{
      for (final entry in raw.entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    };
    return NudgeStats(
      totalNudges: (json['total_nudges'] as num?)?.toInt() ?? 0,
      todayNudges: (json['today_nudges'] as num?)?.toInt() ?? 0,
      thisWeekNudges: (json['this_week_nudges'] as num?)?.toInt() ?? 0,
      totalSuppressed: (json['total_suppressed'] as num?)?.toInt() ?? 0,
      suppressedByReason: reasons,
    );
  }
}
