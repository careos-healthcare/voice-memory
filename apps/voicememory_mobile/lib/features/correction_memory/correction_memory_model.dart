import '../current_relevance/current_relevance_model.dart';

/// User correction weight for how the archive talks about a pattern.
enum CorrectionMemoryState { stillCurrent, partlyCurrent, faded, unsure }

extension CorrectionMemoryStateAnalytics on CorrectionMemoryState {
  String get analyticsValue => switch (this) {
    CorrectionMemoryState.stillCurrent => 'still_current',
    CorrectionMemoryState.partlyCurrent => 'partly_current',
    CorrectionMemoryState.faded => 'faded',
    CorrectionMemoryState.unsure => 'unsure',
  };
}

extension CorrectionMemoryStateMapping on CurrentRelevanceAnswer {
  CorrectionMemoryState toCorrectionMemoryState() => switch (this) {
    CurrentRelevanceAnswer.yes => CorrectionMemoryState.stillCurrent,
    CurrentRelevanceAnswer.little => CorrectionMemoryState.partlyCurrent,
    CurrentRelevanceAnswer.notReally => CorrectionMemoryState.faded,
    CurrentRelevanceAnswer.notSure => CorrectionMemoryState.unsure,
  };
}

/// Local correction record — proof key only, never transcript text.
class CorrectionMemoryRecord {
  const CorrectionMemoryRecord({
    required this.proofKey,
    required this.state,
    required this.entryCountAtCapture,
    required this.hasConfirmedRepeat,
    required this.correctedAt,
  });

  final String proofKey;
  final CorrectionMemoryState state;
  final int entryCountAtCapture;
  final bool hasConfirmedRepeat;
  final DateTime correctedAt;

  Map<String, dynamic> toJson() => {
    'proofKey': proofKey,
    'state': state.analyticsValue,
    'entryCountAtCapture': entryCountAtCapture,
    'hasConfirmedRepeat': hasConfirmedRepeat,
    'correctedAt': correctedAt.toUtc().toIso8601String(),
  };

  factory CorrectionMemoryRecord.fromJson(Map<String, dynamic> json) {
    final stateRaw = json['state']?.toString() ?? '';
    return CorrectionMemoryRecord(
      proofKey: json['proofKey']?.toString() ?? '',
      state: CorrectionMemoryState.values.firstWhere(
        (value) => value.analyticsValue == stateRaw,
        orElse: () => CorrectionMemoryState.unsure,
      ),
      entryCountAtCapture: json['entryCountAtCapture'] as int? ?? 0,
      hasConfirmedRepeat: json['hasConfirmedRepeat'] as bool? ?? false,
      correctedAt:
          DateTime.tryParse(json['correctedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Lightweight correction view for other engines.
class CorrectionMemorySnapshot {
  const CorrectionMemorySnapshot({
    required this.state,
    required this.returnedAfterFaded,
    required this.entryCountAtCapture,
  });

  final CorrectionMemoryState state;
  final bool returnedAfterFaded;
  final int entryCountAtCapture;
}

/// Resolved correction card content.
class CorrectionMemoryResult {
  const CorrectionMemoryResult({
    required this.shouldShow,
    required this.proofKey,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.state,
    required this.returnedAfterFaded,
    required this.title,
    required this.body,
    required this.footer,
    required this.differentiationLine,
  });

  final bool shouldShow;
  final String proofKey;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final CorrectionMemoryState state;
  final bool returnedAfterFaded;
  final String title;
  final String body;
  final String footer;
  final String differentiationLine;

  CorrectionMemorySnapshot get snapshot => CorrectionMemorySnapshot(
    state: state,
    returnedAfterFaded: returnedAfterFaded,
    entryCountAtCapture: entryCount,
  );
}
