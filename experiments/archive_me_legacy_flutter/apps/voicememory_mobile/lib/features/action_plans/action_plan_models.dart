import 'dart:collection';

enum ActionPlanStatus { active, paused, completed }

enum ActionPlanFrequencyType { daily, customDays }

/// A schedule expressed using ISO weekdays (`DateTime.monday` through Sunday).
final class ActionPlanFrequency {
  ActionPlanFrequency.daily()
    : type = ActionPlanFrequencyType.daily,
      weekdays = const {};

  ActionPlanFrequency.customDays(Iterable<int> weekdays)
    : type = ActionPlanFrequencyType.customDays,
      weekdays = _weekdays(weekdays);

  final ActionPlanFrequencyType type;
  final Set<int> weekdays;

  bool isScheduled(DateTime date) =>
      type == ActionPlanFrequencyType.daily || weekdays.contains(date.weekday);

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (type == ActionPlanFrequencyType.customDays)
      'weekdays': weekdays.toList()..sort(),
  };

  factory ActionPlanFrequency.fromJson(Map<String, dynamic> json) {
    _strictKeys(json, const {'type', 'weekdays'}, 'frequency');
    final rawType = json['type'];
    if (rawType is! String) {
      throw const FormatException('Invalid action plan frequency.');
    }
    final type = ActionPlanFrequencyType.values
        .where((value) => value.name == rawType)
        .firstOrNull;
    if (type == null) {
      throw const FormatException('Invalid action plan frequency type.');
    }
    if (type == ActionPlanFrequencyType.daily) {
      if (json.containsKey('weekdays')) {
        throw const FormatException('Daily frequency cannot have weekdays.');
      }
      return ActionPlanFrequency.daily();
    }
    final days = json['weekdays'];
    if (days is! List || days.any((value) => value is! int)) {
      throw const FormatException('Invalid custom weekdays.');
    }
    return ActionPlanFrequency.customDays(days.cast<int>());
  }
}

typedef MicroHabitFrequency = ActionPlanFrequency;

final class MicroHabitStep {
  MicroHabitStep({
    required String id,
    required String planId,
    required String title,
    required this.frequency,
    required String targetNodeId,
    this.streakCount = 0,
    Map<String, bool> completionHistory = const {},
  }) : id = _required(id, 'id'),
       planId = _required(planId, 'planId'),
       title = _required(title, 'title'),
       targetNodeId = _required(targetNodeId, 'targetNodeId'),
       completionHistory = _history(completionHistory) {
    if (streakCount < 0) {
      throw ArgumentError.value(streakCount, 'streakCount', 'must be >= 0');
    }
  }

  final String id;
  final String planId;
  final String title;
  final ActionPlanFrequency frequency;
  final String targetNodeId;
  final int streakCount;
  final Map<String, bool> completionHistory;

  MicroHabitStep copyWith({
    String? title,
    ActionPlanFrequency? frequency,
    String? targetNodeId,
    int? streakCount,
    Map<String, bool>? completionHistory,
  }) => MicroHabitStep(
    id: id,
    planId: planId,
    title: title ?? this.title,
    frequency: frequency ?? this.frequency,
    targetNodeId: targetNodeId ?? this.targetNodeId,
    streakCount: streakCount ?? this.streakCount,
    completionHistory: completionHistory ?? this.completionHistory,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'planId': planId,
    'title': title,
    'frequency': frequency.toJson(),
    'targetNodeId': targetNodeId,
    'streakCount': streakCount,
    'completionHistory': completionHistory,
  };

  factory MicroHabitStep.fromJson(Map<String, dynamic> json) {
    _strictKeys(json, const {
      'id',
      'planId',
      'title',
      'frequency',
      'targetNodeId',
      'streakCount',
      'completionHistory',
    }, 'micro habit step');
    final frequency = json['frequency'];
    final streak = json['streakCount'];
    final history = json['completionHistory'];
    if (json['id'] is! String ||
        json['planId'] is! String ||
        json['title'] is! String ||
        frequency is! Map ||
        json['targetNodeId'] is! String ||
        streak is! int ||
        history is! Map ||
        history.entries.any(
          (entry) => entry.key is! String || entry.value is! bool,
        )) {
      throw const FormatException('Invalid micro habit step.');
    }
    return MicroHabitStep(
      id: json['id'] as String,
      planId: json['planId'] as String,
      title: json['title'] as String,
      frequency: ActionPlanFrequency.fromJson(
        Map<String, dynamic>.from(frequency),
      ),
      targetNodeId: json['targetNodeId'] as String,
      streakCount: streak,
      completionHistory: Map<String, bool>.from(history),
    );
  }
}

final class ActionPlan {
  ActionPlan({
    required String id,
    String? clusterId,
    String? simulationId,
    required String title,
    required String targetOutcome,
    required DateTime createdAt,
    this.status = ActionPlanStatus.active,
    Iterable<MicroHabitStep> steps = const [],
  }) : id = _required(id, 'id'),
       clusterId = _optional(clusterId),
       simulationId = _optional(simulationId),
       title = _required(title, 'title'),
       targetOutcome = _required(targetOutcome, 'targetOutcome'),
       createdAt = createdAt.toUtc(),
       steps = _steps(steps, id) {
    if ((this.clusterId == null) == (this.simulationId == null)) {
      throw ArgumentError(
        'Exactly one of clusterId or simulationId is required.',
      );
    }
  }

  final String id;
  final String? clusterId;
  final String? simulationId;
  final String title;
  final String targetOutcome;
  final DateTime createdAt;
  final ActionPlanStatus status;
  final List<MicroHabitStep> steps;

  ActionPlan copyWith({
    String? title,
    String? targetOutcome,
    ActionPlanStatus? status,
    Iterable<MicroHabitStep>? steps,
  }) => ActionPlan(
    id: id,
    clusterId: clusterId,
    simulationId: simulationId,
    title: title ?? this.title,
    targetOutcome: targetOutcome ?? this.targetOutcome,
    createdAt: createdAt,
    status: status ?? this.status,
    steps: steps ?? this.steps,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clusterId': clusterId,
    'simulationId': simulationId,
    'title': title,
    'targetOutcome': targetOutcome,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'steps': steps.map((step) => step.toJson()).toList(),
  };

  Map<String, dynamic> toPortableJson() => toJson();

  factory ActionPlan.fromJson(Map<String, dynamic> json) {
    _strictKeys(json, const {
      'id',
      'clusterId',
      'simulationId',
      'title',
      'targetOutcome',
      'createdAt',
      'status',
      'steps',
    }, 'action plan');
    final createdAt = json['createdAt'];
    final rawStatus = json['status'];
    final rawSteps = json['steps'];
    if (json['id'] is! String ||
        json['clusterId'] != null && json['clusterId'] is! String ||
        json['simulationId'] != null && json['simulationId'] is! String ||
        json['title'] is! String ||
        json['targetOutcome'] is! String ||
        createdAt is! String ||
        rawStatus is! String ||
        rawSteps is! List ||
        rawSteps.any((step) => step is! Map)) {
      throw const FormatException('Invalid action plan.');
    }
    final timestamp = DateTime.tryParse(createdAt);
    final status = ActionPlanStatus.values
        .where((value) => value.name == rawStatus)
        .firstOrNull;
    if (timestamp == null || status == null) {
      throw const FormatException('Invalid action plan value.');
    }
    return ActionPlan(
      id: json['id'] as String,
      clusterId: json['clusterId'] as String?,
      simulationId: json['simulationId'] as String?,
      title: json['title'] as String,
      targetOutcome: json['targetOutcome'] as String,
      createdAt: timestamp,
      status: status,
      steps: rawSteps.map(
        (step) =>
            MicroHabitStep.fromJson(Map<String, dynamic>.from(step as Map)),
      ),
    );
  }
}

final class ActionPlanCheckInResult {
  ActionPlanCheckInResult({
    required this.plan,
    required this.step,
    required this.alreadyCheckedIn,
    Iterable<String> reinforcedNodeIds = const [],
    Iterable<String> reinforcedEdgeIds = const [],
    this.milestoneReached,
  }) : reinforcedNodeIds = List.unmodifiable(reinforcedNodeIds),
       reinforcedEdgeIds = List.unmodifiable(reinforcedEdgeIds);

  final ActionPlan plan;
  final MicroHabitStep step;
  final bool alreadyCheckedIn;
  final List<String> reinforcedNodeIds;
  final List<String> reinforcedEdgeIds;
  final int? milestoneReached;

  List<String> get reinforcedIds =>
      List.unmodifiable({...reinforcedNodeIds, ...reinforcedEdgeIds});
}

String canonicalActionPlanDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}

DateTime parseCanonicalActionPlanDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Invalid canonical date: $value');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00.000Z');
  if (parsed == null || canonicalActionPlanDate(parsed) != value) {
    throw FormatException('Invalid canonical date: $value');
  }
  return parsed;
}

Set<int> _weekdays(Iterable<int> values) {
  final result = values.toSet();
  if (result.isEmpty ||
      result.any(
        (value) => value < DateTime.monday || value > DateTime.sunday,
      )) {
    throw ArgumentError.value(values, 'weekdays', 'must contain ISO weekdays');
  }
  return Set.unmodifiable(result);
}

Map<String, bool> _history(Map<String, bool> values) {
  final sorted = SplayTreeMap<String, bool>();
  for (final entry in values.entries) {
    parseCanonicalActionPlanDate(entry.key);
    sorted[entry.key] = entry.value;
  }
  return Map.unmodifiable(sorted);
}

List<MicroHabitStep> _steps(Iterable<MicroHabitStep> values, String planId) {
  final byId = <String, MicroHabitStep>{};
  for (final step in values) {
    if (step.planId != planId) {
      throw ArgumentError.value(step.planId, 'steps', 'must match plan ID');
    }
    if (byId.containsKey(step.id)) {
      throw ArgumentError.value(step.id, 'steps', 'duplicate step ID');
    }
    byId[step.id] = step;
  }
  final result = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(result);
}

String _required(String value, String field) {
  final result = value.trim();
  if (result.isEmpty) {
    throw ArgumentError.value(value, field, 'must not be empty');
  }
  return result;
}

String? _optional(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

void _strictKeys(Map<String, dynamic> json, Set<String> keys, String type) {
  if (json.keys.any((key) => !keys.contains(key))) {
    throw FormatException('Unknown $type field.');
  }
}
