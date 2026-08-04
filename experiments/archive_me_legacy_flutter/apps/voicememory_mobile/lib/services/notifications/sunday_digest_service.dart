import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/tomorrow_return/check_in_reminder_service.dart';
import '../../features/weekly_intelligence/weekly_intelligence_models.dart';
import '../../storage/mobile_prefs_store.dart';

typedef SundayDigestPrefetch = Future<WeeklyIntelligenceSnapshot?> Function();

class SundayDigestService {
  SundayDigestService({
    required this.prefs,
    required this.backend,
    required this.prefetch,
    this.clock = DateTime.now,
  });

  static const stateKey = 'sundayWeeklyIntelligenceDigest_v1';
  static const notificationId = 'sunday-weekly-intelligence';
  static const payloadPrefix = 'sunday_weekly_intelligence_v1:';
  static const title = 'Your Sunday Behavioral Intelligence is ready';
  static const body = 'See what actually changed in your patterns this week.';

  final MobilePrefsStore prefs;
  final CheckInReminderBackend backend;
  final SundayDigestPrefetch prefetch;
  final DateTime Function() clock;

  Future<ReminderScheduleOutcome> setEnabled(bool enabled) async {
    await prefs.writeBool('${stateKey}_enabled', enabled);
    if (!enabled) {
      await backend.cancel(notificationId);
      return ReminderScheduleOutcome.disabled;
    }
    if (!backend.isAvailable) return ReminderScheduleOutcome.notAvailable;
    await backend.initialize();
    if (!await backend.requestPermission()) {
      return ReminderScheduleOutcome.permissionDenied;
    }
    await scheduleNext();
    return ReminderScheduleOutcome.scheduled;
  }

  Future<void> reconcile() async {
    if (await prefs.readBool('${stateKey}_enabled') != true) return;
    if (!backend.isAvailable) return;
    await backend.initialize();
    await scheduleNext();
    await prefetchIfDue();
  }

  Future<DateTime> scheduleNext() async {
    final when = nextSunday(clock());
    await backend.schedule(
      checkInId: notificationId,
      title: title,
      body: body,
      when: when,
      payload: '$payloadPrefix${_weekKey(when)}',
    );
    await prefs.writeMap(stateKey, {
      ...?await prefs.readMap(stateKey),
      'scheduledAt': when.toUtc().toIso8601String(),
    });
    return when;
  }

  Future<WeeklyIntelligenceSnapshot?> prefetchIfDue() async {
    final now = clock();
    final cached = await loadCached();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (!isWeekend && cached != null) return cached;
    try {
      final fresh = await prefetch();
      if (fresh == null) return cached;
      await cache(fresh);
      return fresh;
    } on Object {
      return cached;
    }
  }

  Future<void> cache(WeeklyIntelligenceSnapshot snapshot) async {
    await prefs.updateMap(
      stateKey,
      (current) => {
        ...?current,
        'snapshot': _snapshotToJson(snapshot),
        'cachedAt': clock().toUtc().toIso8601String(),
      },
    );
  }

  Future<WeeklyIntelligenceSnapshot?> loadCached() async {
    final raw = (await prefs.readMap(stateKey))?['snapshot'];
    if (raw is! Map) return null;
    try {
      return _snapshotFromJson(Map<String, dynamic>.from(raw)).asCached();
    } on Object {
      return null;
    }
  }

  static DateTime nextSunday(DateTime now, {int hour = 9}) {
    final local = DateTime(now.year, now.month, now.day, hour);
    var days = (DateTime.sunday - now.weekday) % 7;
    if (days == 0 && !local.isAfter(now)) days = 7;
    return local.add(Duration(days: days));
  }

  static String _weekKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _snapshotToJson(
    WeeklyIntelligenceSnapshot snapshot,
  ) => {
    'weekStart': snapshot.weekStart.toIso8601String(),
    'weekEnd': snapshot.weekEnd.toIso8601String(),
    'baselineWeekCount': snapshot.baselineWeekCount,
    'localSemanticMatches': snapshot.localSemanticMatches,
    'generatedAt': snapshot.generatedAt.toIso8601String(),
    'deltas': [
      for (final delta in snapshot.deltas)
        {
          'id': delta.id,
          'dimension': delta.dimension.name,
          'title': delta.title,
          'statement': delta.statement,
          'magnitude': delta.magnitude,
          'direction': delta.direction.name,
          'nodeIds': delta.nodeIds.toList(),
          'explainability': {
            'confidence': delta.explainability.confidence,
            'reasoning': delta.explainability.reasoning,
            'alternativeExplanation':
                delta.explainability.alternativeExplanation,
            'uncertainty': delta.explainability.uncertainty,
            'evidence': [
              for (final citation in delta.explainability.evidence)
                {
                  'sourceEntryId': citation.sourceEntryId,
                  'exactQuote': citation.exactQuote,
                  'audioTimestampMs': citation.audioTimestampMs,
                  'confidenceScore': citation.confidenceScore,
                  'startUtf16': citation.startUtf16,
                  'endUtf16': citation.endUtf16,
                },
            ],
          },
        },
    ],
  };

  static WeeklyIntelligenceSnapshot _snapshotFromJson(
    Map<String, dynamic> json,
  ) => WeeklyIntelligenceSnapshot(
    weekStart: DateTime.parse(json['weekStart'] as String).toUtc(),
    weekEnd: DateTime.parse(json['weekEnd'] as String).toUtc(),
    baselineWeekCount: json['baselineWeekCount'] as int,
    localSemanticMatches: json['localSemanticMatches'] as int,
    generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
    deltas: (json['deltas'] as List)
        .map((raw) => _deltaFromJson(Map<String, dynamic>.from(raw as Map)))
        .toList(),
  );

  static BehavioralDelta _deltaFromJson(Map<String, dynamic> json) {
    final explanation = Map<String, dynamic>.from(
      json['explainability'] as Map,
    );
    final explainability = AiExplainability(
      confidence: explanation['confidence'] as int,
      evidence: (explanation['evidence'] as List).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return VerifiableCitation(
          sourceEntryId: item['sourceEntryId'] as String,
          exactQuote: item['exactQuote'] as String,
          audioTimestampMs: item['audioTimestampMs'] as int?,
          confidenceScore: (item['confidenceScore'] as num).toDouble(),
          startUtf16: item['startUtf16'] as int?,
          endUtf16: item['endUtf16'] as int?,
        );
      }).toList(),
      reasoning: List<String>.from(explanation['reasoning'] as List),
      alternativeExplanation: explanation['alternativeExplanation'] as String,
      uncertainty: explanation['uncertainty'] as String,
    );
    final id = json['id'] as String;
    final title = json['title'] as String;
    final statement = json['statement'] as String;
    final magnitude = (json['magnitude'] as num).toDouble();
    final direction = DeltaDirection.values.byName(json['direction'] as String);
    final nodeIds = Set<String>.from(json['nodeIds'] as List);
    return switch (json['dimension']) {
      'actionIntentRatio' => ActionIntentRatio(
        id: id,
        title: title,
        statement: statement,
        magnitude: magnitude,
        direction: direction,
        nodeIds: nodeIds,
        explainability: explainability,
        baselineIntentCount: 0,
        currentActionCount: 0,
        executionRatio: magnitude,
      ),
      'emotionalVelocity' => EmotionalVelocity(
        id: id,
        title: title,
        statement: statement,
        magnitude: magnitude,
        direction: direction,
        nodeIds: nodeIds,
        explainability: explainability,
        baselineTone: 0,
        currentTone: magnitude,
      ),
      'habitDrift' => HabitDrift(
        id: id,
        title: title,
        statement: statement,
        magnitude: magnitude,
        direction: direction,
        nodeIds: nodeIds,
        explainability: explainability,
        habitLabel: title,
        baselineWeeklyMentions: 0,
        currentMentions: 0,
        frictionPoints: const [],
      ),
      'relationshipDynamics' => RelationshipDynamicsDelta(
        id: id,
        title: title,
        statement: statement,
        magnitude: magnitude,
        direction: direction,
        nodeIds: nodeIds,
        explainability: explainability,
        personLabel: title,
        frequencyDelta: 0,
        valenceDelta: magnitude,
      ),
      'identityShift' => IdentityShiftDelta(
        id: id,
        title: title,
        statement: statement,
        magnitude: magnitude,
        direction: direction,
        nodeIds: nodeIds,
        explainability: explainability,
        previousBelief: '',
        currentBelief: statement,
      ),
      _ => throw const FormatException('Unknown cached weekly delta.'),
    };
  }
}
