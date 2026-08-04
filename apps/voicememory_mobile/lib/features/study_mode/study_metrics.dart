/// The complete set of things a study build is allowed to count.
///
/// Callers pass an enum, never a string, so no site can invent a signal name
/// that smuggles content through the counter key.
enum StudySignal {
  appOpened,
  captureStarted,
  captureCompleted,
  captureAbandoned,
  resultViewed,
  returnVisit,
  helpOpened,
  errorShown,
  feedbackSubmitted,
}

extension StudySignalToken on StudySignal {
  /// Stable wire name. Kept explicit so renaming the enum cannot silently
  /// change the shape of an in-flight study's data.
  String get token => switch (this) {
    StudySignal.appOpened => 'app_opened',
    StudySignal.captureStarted => 'capture_started',
    StudySignal.captureCompleted => 'capture_completed',
    StudySignal.captureAbandoned => 'capture_abandoned',
    StudySignal.resultViewed => 'result_viewed',
    StudySignal.returnVisit => 'return_visit',
    StudySignal.helpOpened => 'help_opened',
    StudySignal.errorShown => 'error_shown',
    StudySignal.feedbackSubmitted => 'feedback_submitted',
  };
}

/// Counts, dates, and nothing else.
///
/// There is no field here that can hold saved words, a title, a note, or any
/// other thing a participant said. The type itself is the guarantee.
final class StudyMetrics {
  const StudyMetrics({
    required this.archiveId,
    this.counts = const {},
    this.activeDays = const {},
    this.firstSignalAt,
    this.lastSignalAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const currentSchemaVersion = 1;

  final String archiveId;
  final Map<StudySignal, int> counts;

  /// UTC calendar days (`yyyy-MM-dd`) on which any signal was recorded.
  final Set<String> activeDays;
  final DateTime? firstSignalAt;
  final DateTime? lastSignalAt;
  final int schemaVersion;

  bool get isEmpty => counts.isEmpty;

  int countOf(StudySignal signal) => counts[signal] ?? 0;

  int get activeDayCount => activeDays.length;

  StudyMetrics recording(StudySignal signal, {required DateTime at}) {
    final utc = at.toUtc();
    return StudyMetrics(
      archiveId: archiveId,
      counts: {...counts, signal: countOf(signal) + 1},
      activeDays: {...activeDays, dayKey(utc)},
      firstSignalAt: firstSignalAt == null || utc.isBefore(firstSignalAt!)
          ? utc
          : firstSignalAt,
      lastSignalAt: lastSignalAt == null || utc.isAfter(lastSignalAt!)
          ? utc
          : lastSignalAt,
      schemaVersion: schemaVersion,
    );
  }

  static String dayKey(DateTime at) =>
      at.toUtc().toIso8601String().substring(0, 10);

  /// Every catalogued signal, including the ones never seen, so a study export
  /// distinguishes "did not happen" from "not measured".
  Map<String, Object?> toSignalTotals() => {
    for (final signal in StudySignal.values) signal.token: countOf(signal),
  };

  Map<String, Object?> toJson() => {
    'archiveId': archiveId,
    'counts': {
      for (final entry in counts.entries) entry.key.token: entry.value,
    },
    'activeDays': activeDays.toList(growable: false)..sort(),
    'firstSignalAt': firstSignalAt?.toIso8601String(),
    'lastSignalAt': lastSignalAt?.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  static StudyMetrics? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final archiveId = json['archiveId']?.toString().trim() ?? '';
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (archiveId.isEmpty || schemaVersion != currentSchemaVersion) return null;

    final byToken = {
      for (final signal in StudySignal.values) signal.token: signal,
    };
    final counts = <StudySignal, int>{};
    final rawCounts = json['counts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final signal = byToken[entry.key.toString()];
        final count = (entry.value as num?)?.toInt();
        // An unrecognised or negative counter is dropped rather than carried,
        // so a tampered file cannot inject a key into an export.
        if (signal == null || count == null || count < 0) continue;
        counts[signal] = count;
      }
    }

    return StudyMetrics(
      archiveId: archiveId,
      counts: counts,
      activeDays: {
        for (final day in (json['activeDays'] as List? ?? const []))
          if (_dayShape.hasMatch(day.toString())) day.toString(),
      },
      firstSignalAt: DateTime.tryParse(json['firstSignalAt']?.toString() ?? ''),
      lastSignalAt: DateTime.tryParse(json['lastSignalAt']?.toString() ?? ''),
      schemaVersion: schemaVersion!,
    );
  }

  static final _dayShape = RegExp(r'^\d{4}-\d{2}-\d{2}$');
}
