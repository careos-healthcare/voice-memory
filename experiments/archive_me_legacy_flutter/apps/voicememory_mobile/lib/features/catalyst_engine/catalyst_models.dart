enum CatalystTriggerKind {
  journalChanged,
  graphChanged,
  transcriptionCompleted,
  firstUnlock,
  scheduleTick,
  manual,
}

enum CatalystConditionOperator {
  equals,
  notEquals,
  contains,
  greaterThan,
  lessThan,
  exists,
}

enum CatalystActionKind {
  tagNode,
  rebuildClusters,
  queueOrphanBridge,
  councilPrompt,
  encryptedExport,
  museSweep,
  vaultHygiene,
  sandboxModule,
}

enum CatalystRunStatus {
  running,
  succeeded,
  failed,
  timedOut,
  cancelled,
  awaitingApproval,
  capabilityUnavailable,
  dryRun,
}

final class CatalystTrigger {
  const CatalystTrigger(this.kind, {this.configuration = const {}});

  final CatalystTriggerKind kind;
  final Map<String, Object?> configuration;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'configuration': configuration,
  };

  factory CatalystTrigger.fromJson(Map<String, Object?> json) =>
      CatalystTrigger(
        CatalystTriggerKind.values.byName(json['kind']! as String),
        configuration: Map<String, Object?>.from(
          json['configuration'] as Map? ?? const {},
        ),
      );
}

final class CatalystCondition {
  const CatalystCondition({
    required this.field,
    required this.operator,
    this.value,
  });

  final String field;
  final CatalystConditionOperator operator;
  final Object? value;

  Map<String, Object?> toJson() => {
    'field': field,
    'operator': operator.name,
    'value': value,
  };

  factory CatalystCondition.fromJson(Map<String, Object?> json) =>
      CatalystCondition(
        field: json['field']! as String,
        operator: CatalystConditionOperator.values.byName(
          json['operator']! as String,
        ),
        value: json['value'],
      );
}

final class CatalystAction {
  const CatalystAction({
    required this.id,
    required this.kind,
    this.arguments = const {},
    this.timeout = const Duration(seconds: 15),
    this.requiresOwnerApproval = false,
  });

  final String id;
  final CatalystActionKind kind;
  final Map<String, Object?> arguments;
  final Duration timeout;
  final bool requiresOwnerApproval;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'arguments': arguments,
    'timeoutMs': timeout.inMilliseconds,
    'requiresOwnerApproval': requiresOwnerApproval,
  };

  factory CatalystAction.fromJson(Map<String, Object?> json) => CatalystAction(
    id: json['id']! as String,
    kind: CatalystActionKind.values.byName(json['kind']! as String),
    arguments: Map<String, Object?>.from(json['arguments'] as Map? ?? const {}),
    timeout: Duration(
      milliseconds: (json['timeoutMs'] as num?)?.toInt() ?? 15000,
    ),
    requiresOwnerApproval: json['requiresOwnerApproval'] as bool? ?? false,
  );
}

final class CatalystRecipe {
  CatalystRecipe({
    required this.id,
    required this.name,
    required this.trigger,
    required Iterable<CatalystAction> actions,
    Iterable<CatalystCondition> conditions = const [],
    this.enabled = true,
    this.templateId,
    this.schemaVersion = 1,
  }) : conditions = List.unmodifiable(conditions),
       actions = List.unmodifiable(actions) {
    if (id.isEmpty || name.trim().isEmpty || actions.isEmpty) {
      throw const FormatException('Catalyst recipe is incomplete.');
    }
    if (actions.length > 20 || conditions.length > 20) {
      throw const FormatException('Catalyst recipe exceeds step limits.');
    }
    final ids = actions.map((action) => action.id).toSet();
    if (ids.length != actions.length) {
      throw const FormatException('Catalyst action ids must be unique.');
    }
  }

  final int schemaVersion;
  final String id;
  final String name;
  final bool enabled;
  final String? templateId;
  final CatalystTrigger trigger;
  final List<CatalystCondition> conditions;
  final List<CatalystAction> actions;

  CatalystRecipe copyWith({
    bool? enabled,
    String? name,
    CatalystTrigger? trigger,
    Iterable<CatalystCondition>? conditions,
    Iterable<CatalystAction>? actions,
  }) => CatalystRecipe(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    templateId: templateId,
    trigger: trigger ?? this.trigger,
    conditions: conditions ?? this.conditions,
    actions: actions ?? this.actions,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'enabled': enabled,
    'templateId': templateId,
    'trigger': trigger.toJson(),
    'conditions': conditions.map((item) => item.toJson()).toList(),
    'actions': actions.map((item) => item.toJson()).toList(),
  };

  factory CatalystRecipe.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Catalyst recipe schema.');
    }
    return CatalystRecipe(
      id: json['id']! as String,
      name: json['name']! as String,
      enabled: json['enabled'] as bool? ?? false,
      templateId: json['templateId'] as String?,
      trigger: CatalystTrigger.fromJson(
        Map<String, Object?>.from(json['trigger']! as Map),
      ),
      conditions: (json['conditions'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                CatalystCondition.fromJson(Map<String, Object?>.from(item)),
          ),
      actions: (json['actions'] as List? ?? const []).whereType<Map>().map(
        (item) => CatalystAction.fromJson(Map<String, Object?>.from(item)),
      ),
    );
  }
}

final class CatalystEvent {
  CatalystEvent({
    required this.id,
    required this.kind,
    required DateTime occurredAt,
    this.payload = const {},
    this.background = false,
  }) : occurredAt = occurredAt.toUtc();

  final String id;
  final CatalystTriggerKind kind;
  final DateTime occurredAt;
  final Map<String, Object?> payload;
  final bool background;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'occurredAt': occurredAt.toIso8601String(),
    'payload': payload,
    'background': background,
  };

  factory CatalystEvent.fromJson(Map<String, Object?> json) => CatalystEvent(
    id: json['id']! as String,
    kind: CatalystTriggerKind.values.byName(json['kind']! as String),
    occurredAt: DateTime.parse(json['occurredAt']! as String),
    payload: Map<String, Object?>.from(json['payload'] as Map? ?? const {}),
    background: json['background'] as bool? ?? false,
  );
}

final class CatalystRunLog {
  CatalystRunLog({
    required this.id,
    required this.recipeId,
    required this.eventId,
    required this.status,
    required DateTime startedAt,
    required DateTime finishedAt,
    required this.completedActionIds,
    this.message,
    this.output,
    this.elapsedMicroseconds = 0,
  }) : startedAt = startedAt.toUtc(),
       finishedAt = finishedAt.toUtc();

  final String id;
  final String recipeId;
  final String eventId;
  final CatalystRunStatus status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<String> completedActionIds;
  final String? message;
  final String? output;
  final int elapsedMicroseconds;

  Map<String, Object?> toJson() => {
    'id': id,
    'recipeId': recipeId,
    'eventId': eventId,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'completedActionIds': completedActionIds,
    'message': message,
    'output': _truncate(output, 4000),
    'elapsedMicroseconds': elapsedMicroseconds,
  };

  factory CatalystRunLog.fromJson(Map<String, Object?> json) => CatalystRunLog(
    id: json['id']! as String,
    recipeId: json['recipeId']! as String,
    eventId: json['eventId']! as String,
    status: CatalystRunStatus.values.byName(json['status']! as String),
    startedAt: DateTime.parse(json['startedAt']! as String),
    finishedAt: DateTime.parse(json['finishedAt']! as String),
    completedActionIds: (json['completedActionIds'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    message: json['message'] as String?,
    output: json['output'] as String?,
    elapsedMicroseconds: (json['elapsedMicroseconds'] as num?)?.toInt() ?? 0,
  );
}

String? _truncate(String? value, int maximum) =>
    value?.substring(0, value.length.clamp(0, maximum).toInt());

final class CatalystApproval {
  CatalystApproval({
    required this.id,
    required this.recipeId,
    required this.event,
    required this.actionIndex,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();

  final String id;
  final String recipeId;
  final CatalystEvent event;
  final int actionIndex;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'recipeId': recipeId,
    'event': event.toJson(),
    'actionIndex': actionIndex,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CatalystApproval.fromJson(Map<String, Object?> json) =>
      CatalystApproval(
        id: json['id']! as String,
        recipeId: json['recipeId']! as String,
        event: CatalystEvent.fromJson(
          Map<String, Object?>.from(json['event']! as Map),
        ),
        actionIndex: (json['actionIndex'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt']! as String),
      );
}
