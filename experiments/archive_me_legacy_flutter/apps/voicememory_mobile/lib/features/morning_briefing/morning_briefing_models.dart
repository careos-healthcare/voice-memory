import 'dart:collection';

enum MorningBriefingSectionKind {
  restAndRecovery,
  mindMapMomentum,
  todaysSingleFocus,
}

class MorningBriefingSection {
  MorningBriefingSection({
    required this.kind,
    required String title,
    required String narrative,
  }) : title = _required(title, 'title'),
       narrative = _required(narrative, 'narrative');

  final MorningBriefingSectionKind kind;
  final String title;
  final String narrative;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'narrative': narrative,
  };

  factory MorningBriefingSection.fromJson(Map<String, dynamic> json) {
    final kind = MorningBriefingSectionKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    if (kind == null ||
        json['title'] is! String ||
        json['narrative'] is! String) {
      throw const FormatException('Invalid morning briefing section.');
    }
    return MorningBriefingSection(
      kind: kind,
      title: json['title'] as String,
      narrative: json['narrative'] as String,
    );
  }
}

class MorningBriefing {
  MorningBriefing({
    required String id,
    required DateTime localDay,
    required DateTime generatedAt,
    required Iterable<MorningBriefingSection> sections,
    required this.sleepQualityScore,
    required this.activeHabitCount,
    required this.bestHabitRun,
    this.highlightedNodeId,
    this.highlightedClusterId,
    this.generatedOffline = false,
    this.encryptedAudioAvailable = false,
    this.museTriageCount = 0,
  }) : id = _required(id, 'id'),
       localDay = DateTime(localDay.year, localDay.month, localDay.day),
       generatedAt = generatedAt.toUtc(),
       sections = _sections(sections) {
    if (sleepQualityScore < 0 || sleepQualityScore > 100) {
      throw ArgumentError.value(sleepQualityScore, 'sleepQualityScore');
    }
    if (activeHabitCount < 0 || bestHabitRun < 0) {
      throw ArgumentError('Habit metrics must be non-negative.');
    }
  }

  final String id;
  final DateTime localDay;
  final DateTime generatedAt;
  final List<MorningBriefingSection> sections;
  final int sleepQualityScore;
  final int activeHabitCount;
  final int bestHabitRun;
  final String? highlightedNodeId;
  final String? highlightedClusterId;
  final bool generatedOffline;
  final bool encryptedAudioAvailable;
  final int museTriageCount;

  String get narration => sections
      .map((section) => '${section.title}. ${section.narrative}')
      .join('\n\n');

  MorningBriefing copyWith({
    bool? encryptedAudioAvailable,
    int? museTriageCount,
  }) => MorningBriefing(
    id: id,
    localDay: localDay,
    generatedAt: generatedAt,
    sections: sections,
    sleepQualityScore: sleepQualityScore,
    activeHabitCount: activeHabitCount,
    bestHabitRun: bestHabitRun,
    highlightedNodeId: highlightedNodeId,
    highlightedClusterId: highlightedClusterId,
    generatedOffline: generatedOffline,
    encryptedAudioAvailable:
        encryptedAudioAvailable ?? this.encryptedAudioAvailable,
    museTriageCount: museTriageCount ?? this.museTriageCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'localDay': _date(localDay),
    'generatedAt': generatedAt.toIso8601String(),
    'sections': sections.map((section) => section.toJson()).toList(),
    'sleepQualityScore': sleepQualityScore,
    'activeHabitCount': activeHabitCount,
    'bestHabitRun': bestHabitRun,
    'highlightedNodeId': highlightedNodeId,
    'highlightedClusterId': highlightedClusterId,
    'generatedOffline': generatedOffline,
    'encryptedAudioAvailable': encryptedAudioAvailable,
    'museTriageCount': museTriageCount,
  };

  factory MorningBriefing.fromJson(Map<String, dynamic> json) {
    final localDay = DateTime.tryParse('${json['localDay']}');
    final generatedAt = DateTime.tryParse('${json['generatedAt']}');
    final rawSections = json['sections'];
    if (json['id'] is! String ||
        localDay == null ||
        generatedAt == null ||
        rawSections is! List ||
        json['sleepQualityScore'] is! num ||
        json['activeHabitCount'] is! num ||
        json['bestHabitRun'] is! num) {
      throw const FormatException('Invalid morning briefing.');
    }
    return MorningBriefing(
      id: json['id'] as String,
      localDay: localDay,
      generatedAt: generatedAt,
      sections: rawSections.map((section) {
        if (section is! Map) {
          throw const FormatException('Invalid morning briefing section.');
        }
        return MorningBriefingSection.fromJson(
          Map<String, dynamic>.from(section),
        );
      }),
      sleepQualityScore: (json['sleepQualityScore'] as num).round(),
      activeHabitCount: (json['activeHabitCount'] as num).round(),
      bestHabitRun: (json['bestHabitRun'] as num).round(),
      highlightedNodeId: json['highlightedNodeId'] as String?,
      highlightedClusterId: json['highlightedClusterId'] as String?,
      generatedOffline: json['generatedOffline'] == true,
      encryptedAudioAvailable: json['encryptedAudioAvailable'] == true,
      museTriageCount: (json['museTriageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MorningBriefingHabitSignal {
  MorningBriefingHabitSignal({
    required String stepId,
    required String title,
    required String targetNodeId,
    required this.currentRun,
  }) : stepId = _required(stepId, 'stepId'),
       title = _required(title, 'title'),
       targetNodeId = _required(targetNodeId, 'targetNodeId') {
    if (currentRun < 0) throw ArgumentError.value(currentRun, 'currentRun');
  }

  final String stepId;
  final String title;
  final String targetNodeId;
  final int currentRun;

  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'title': title,
    'targetNodeId': targetNodeId,
    'currentRun': currentRun,
  };
}

class MorningBriefingClusterSignal {
  MorningBriefingClusterSignal({
    required String clusterId,
    required String label,
    required String category,
    required this.velocity,
    required this.velocityDelta,
    required Iterable<String> nodeIds,
  }) : clusterId = _required(clusterId, 'clusterId'),
       label = _required(label, 'label'),
       category = _required(category, 'category'),
       nodeIds = List.unmodifiable(nodeIds.take(12));

  final String clusterId;
  final String label;
  final String category;
  final double velocity;
  final double velocityDelta;
  final List<String> nodeIds;

  Map<String, dynamic> toJson() => {
    'clusterId': clusterId,
    'label': label,
    'category': category,
    'velocity': velocity,
    'velocityDelta': velocityDelta,
    'nodeIds': nodeIds,
  };
}

class MorningBriefingPayload {
  MorningBriefingPayload({
    required DateTime localDay,
    required this.timezoneOffsetMinutes,
    required this.journalEntryCount,
    required this.journalMinutes,
    required Iterable<String> topicSignals,
    required Iterable<MorningBriefingHabitSignal> incompleteHabits,
    required Iterable<MorningBriefingClusterSignal> clusterSignals,
    this.sleepHours,
    this.restingHeartRate,
    this.museTriageCount = 0,
  }) : localDay = DateTime(localDay.year, localDay.month, localDay.day),
       topicSignals = List.unmodifiable(topicSignals.take(12)),
       incompleteHabits = List.unmodifiable(incompleteHabits.take(12)),
       clusterSignals = List.unmodifiable(clusterSignals.take(12));

  final DateTime localDay;
  final int timezoneOffsetMinutes;
  final int journalEntryCount;
  final int journalMinutes;
  final List<String> topicSignals;
  final List<MorningBriefingHabitSignal> incompleteHabits;
  final List<MorningBriefingClusterSignal> clusterSignals;
  final double? sleepHours;
  final double? restingHeartRate;
  final int museTriageCount;

  int get sleepQualityScore {
    final hours = sleepHours;
    if (hours == null) return 0;
    final distance = (hours - 8).abs();
    return (100 - distance * 18).clamp(0, 100).round();
  }

  Map<String, dynamic> toJson() => {
    'localDay': _date(localDay),
    'timezoneOffsetMinutes': timezoneOffsetMinutes,
    'journalEntryCount': journalEntryCount,
    'journalMinutes': journalMinutes,
    'topicSignals': topicSignals,
    'incompleteHabits': incompleteHabits
        .map((habit) => habit.toJson())
        .toList(),
    'clusterSignals': clusterSignals
        .map((cluster) => cluster.toJson())
        .toList(),
    'sleepHours': sleepHours,
    'restingHeartRate': restingHeartRate,
    'museTriageCount': museTriageCount,
  };
}

class MorningBriefingPreferences {
  const MorningBriefingPreferences({
    this.enabled = true,
    this.hour = 7,
    this.minute = 0,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final int quietHoursStart;
  final int quietHoursEnd;

  bool isQuietAt(DateTime localTime) {
    if (quietHoursStart == quietHoursEnd) return false;
    if (quietHoursStart < quietHoursEnd) {
      return localTime.hour >= quietHoursStart &&
          localTime.hour < quietHoursEnd;
    }
    return localTime.hour >= quietHoursStart || localTime.hour < quietHoursEnd;
  }

  DateTime nextRunAfter(DateTime localNow) {
    var candidate = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(localNow)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    while (isQuietAt(candidate)) {
      candidate = candidate.add(const Duration(hours: 1));
    }
    return candidate;
  }
}

List<MorningBriefingSection> _sections(
  Iterable<MorningBriefingSection> values,
) {
  final byKind = {for (final section in values) section.kind: section};
  if (byKind.length != MorningBriefingSectionKind.values.length) {
    throw ArgumentError('Every morning briefing section is required.');
  }
  return UnmodifiableListView([
    for (final kind in MorningBriefingSectionKind.values) byKind[kind]!,
  ]);
}

String _required(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, field);
  return normalized;
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
