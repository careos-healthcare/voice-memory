import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import 'loop_trigger_map_engine.dart';
import 'loop_trigger_map_model.dart';
import 'monthly_ambition_pressure_review_model.dart';
import 'next_evidence_mission_engine.dart';
import 'prove_enough_contradiction_model.dart';
import 'prove_enough_post_record_engine.dart';
import 'prove_enough_post_record_model.dart';

/// Builds monthly prove_enough stronger/fading review from real journal moments.
class MonthlyAmbitionPressureReviewEngine {
  const MonthlyAmbitionPressureReviewEngine();

  static const minMomentsForDirection = 2;
  static const _postEngine = ProveEnoughPostRecordEngine();
  static const _triggerEngine = LoopTriggerMapEngine();
  static const _missionEngine = NextEvidenceMissionEngine();
  static const _loopEngine = LoopModeEngine();
  static const _excerptMaxChars = 88;

  MonthlyAmbitionPressureReview build({
    required List<JournalEntry> entries,
    List<ProveEnoughContradictionRecord> contradictions = const [],
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final monthLabel = _monthLabel(timestamp);
    final activeLoop = _loopEngine.activate(LoopModeIds.proveEnough);

    final currentEntries = _entriesInMonth(entries, timestamp);
    final priorMonth = timestamp.month == 1
        ? DateTime(timestamp.year - 1, 12, 1)
        : DateTime(timestamp.year, timestamp.month - 1, 1);
    final priorEntries = _entriesInMonth(entries, priorMonth);

    final current = _analyzeMonth(
      currentEntries,
      activeLoop: activeLoop,
      contradictions: contradictions,
    );
    final prior = _analyzeMonth(
      priorEntries,
      activeLoop: activeLoop,
      contradictions: contradictions,
    );

    final triggerMap = _triggerEngine.build(currentEntries);
    final topTriggers = triggerMap.rankedRows
        .take(3)
        .map((row) => '${row.category.label} (${row.count})')
        .toList();

    final direction = _direction(current: current, prior: prior);
    final directionEvidence = _directionEvidence(
      current: current,
      prior: prior,
      direction: direction,
    );

    final latestEntry = currentEntries.isEmpty
        ? null
        : currentEntries.last;
    final nextMission = latestEntry == null
        ? _missionEngine.defaultMission(now: timestamp).mission
        : _missionEngine
            .fromPostRecord(
              postRecord: _postEngine.analyze(
                entryId: latestEntry.id,
                transcript: latestEntry.transcript,
                interpretationReads: const [],
                activeLoop: activeLoop,
              ),
            )
            .mission;

    return MonthlyAmbitionPressureReview(
      monthLabel: monthLabel,
      totalProvingMoments: current.totalProvingMoments,
      pressureMomentCount: current.pressureCount,
      choiceMomentCount: current.choiceCount,
      restGuiltCount: current.restGuiltCount,
      contradictionCount: current.contradictionCount,
      topTriggers: topTriggers,
      direction: direction,
      directionEvidence: directionEvidence,
      whatChanged: _whatChanged(current: current, prior: prior),
      nextMonthMission: nextMission,
      whatRepeated: _whatRepeated(current),
      whatSeemedToCostYou: _whatSeemedToCost(current),
      choiceVsPressureSummary: _choiceVsPressureSummary(current),
      restGuiltSummary: _restGuiltSummary(current),
      triggerMapSummary: _triggerSummary(triggerMap, topTriggers),
    );
  }

  List<JournalEntry> _entriesInMonth(
    List<JournalEntry> entries,
    DateTime month,
  ) {
    return ArchiveEvidenceGuard.eligibleEntries(entries)
        .where(
          (entry) =>
              entry.createdAt.year == month.year &&
              entry.createdAt.month == month.month,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  _MonthStats _analyzeMonth(
    List<JournalEntry> entries, {
    required LoopMode activeLoop,
    required List<ProveEnoughContradictionRecord> contradictions,
  }) {
    final stats = _MonthStats();
    final contradictionEntryIds = contradictions
        .map((row) => row.entryId)
        .whereType<String>()
        .toSet();

    for (final entry in entries) {
      final postRecord = _postEngine.analyze(
        entryId: entry.id,
        transcript: entry.transcript,
        interpretationReads: const [],
        activeLoop: activeLoop,
      );
      if (!_isProvingMoment(
        postRecord,
        entryId: entry.id,
        contradictionEntryIds: contradictionEntryIds,
      )) {
        continue;
      }

      stats.totalProvingMoments += 1;
      final excerpt = _excerpt(entry.transcript);

      if (_isPressure(postRecord)) {
        stats.pressureCount += 1;
        _addExcerpt(stats.pressureExcerpts, excerpt);
      }
      if (_isChoice(postRecord)) {
        stats.choiceCount += 1;
        _addExcerpt(stats.choiceExcerpts, excerpt);
      }
      if (postRecord.restGuiltPresent) {
        stats.restGuiltCount += 1;
        _addExcerpt(stats.restGuiltExcerpts, excerpt);
      }
      if (_isContradiction(
        postRecord,
        entryId: entry.id,
        contradictionEntryIds: contradictionEntryIds,
      )) {
        stats.contradictionCount += 1;
        _addExcerpt(stats.contradictionExcerpts, excerpt);
      }
    }

    return stats;
  }

  bool _isProvingMoment(
    ProveEnoughPostRecordModel postRecord, {
    required String entryId,
    required Set<String> contradictionEntryIds,
  }) {
    if (postRecord.transcriptWeak) return false;
    return _isPressure(postRecord) ||
        _isChoice(postRecord) ||
        postRecord.restGuiltPresent ||
        _isContradiction(
          postRecord,
          entryId: entryId,
          contradictionEntryIds: contradictionEntryIds,
        );
  }

  bool _isPressure(ProveEnoughPostRecordModel postRecord) =>
      postRecord.pressureLevel != ProveEnoughLevel.low ||
      postRecord.enoughnessScore >= 36;

  bool _isChoice(ProveEnoughPostRecordModel postRecord) =>
      postRecord.choiceLevel != ProveEnoughLevel.low;

  bool _isContradiction(
    ProveEnoughPostRecordModel postRecord, {
    required String entryId,
    required Set<String> contradictionEntryIds,
  }) {
    if (contradictionEntryIds.contains(entryId)) return true;
    return postRecord.choiceLevel != ProveEnoughLevel.low &&
        postRecord.pressureLevel == ProveEnoughLevel.low &&
        postRecord.enoughnessScore <= 35;
  }

  AmbitionPressureDirection _direction({
    required _MonthStats current,
    required _MonthStats prior,
  }) {
    if (current.totalProvingMoments < minMomentsForDirection) {
      return AmbitionPressureDirection.unclear;
    }

    final hasConfirmation = current.pressureCount > 0 || current.restGuiltCount > 0;
    final hasChallenge =
        current.choiceCount > 0 || current.contradictionCount > 0;

    if (hasConfirmation && hasChallenge) {
      return AmbitionPressureDirection.mixed;
    }

    if (prior.totalProvingMoments >= minMomentsForDirection) {
      final pressureRatioUp =
          current.pressureRatio > prior.pressureRatio + 0.1;
      final restGuiltUp = current.restGuiltCount > prior.restGuiltCount;
      final contradictionDown =
          current.contradictionCount < prior.contradictionCount;
      final choiceUp = current.choiceCount > prior.choiceCount;
      final pressureDown = current.pressureCount < prior.pressureCount;
      final restGuiltDown = current.restGuiltCount < prior.restGuiltCount;

      if ((pressureRatioUp || restGuiltUp) &&
          (contradictionDown || current.contradictionCount == 0)) {
        return AmbitionPressureDirection.stronger;
      }

      if ((choiceUp || current.contradictionCount > prior.contradictionCount) &&
          (pressureDown || restGuiltDown)) {
        return AmbitionPressureDirection.fading;
      }
    }

    if (hasConfirmation && !hasChallenge) {
      return AmbitionPressureDirection.stronger;
    }
    if (hasChallenge && !hasConfirmation) {
      return AmbitionPressureDirection.fading;
    }

    return AmbitionPressureDirection.unclear;
  }

  List<String> _directionEvidence({
    required _MonthStats current,
    required _MonthStats prior,
    required AmbitionPressureDirection direction,
  }) {
    if (direction == AmbitionPressureDirection.unclear) {
      return const [
        'ArchiveMe needs more proving moments before calling a direction.',
      ];
    }

    final lines = <String>[
      'Pressure moments: ${current.pressureCount} this month'
          '${prior.totalProvingMoments > 0 ? ' vs ${prior.pressureCount} last month' : ''}.',
      'Choice moments: ${current.choiceCount} this month'
          '${prior.totalProvingMoments > 0 ? ' vs ${prior.choiceCount} last month' : ''}.',
      'Rest guilt moments: ${current.restGuiltCount} this month'
          '${prior.totalProvingMoments > 0 ? ' vs ${prior.restGuiltCount} last month' : ''}.',
      'Contradiction moments: ${current.contradictionCount} this month'
          '${prior.totalProvingMoments > 0 ? ' vs ${prior.contradictionCount} last month' : ''}.',
    ];

    if (current.pressureExcerpts.isNotEmpty) {
      lines.add('Recent pressure: ${current.pressureExcerpts.first}');
    }
    if (current.contradictionExcerpts.isNotEmpty) {
      lines.add('Recent challenge: ${current.contradictionExcerpts.first}');
    }

    return lines;
  }

  String _whatChanged({
    required _MonthStats current,
    required _MonthStats prior,
  }) {
    if (prior.totalProvingMoments == 0) {
      return 'This is the first month with enough proving moments to compare.';
    }
    if (current.pressureCount > prior.pressureCount) {
      return 'Pressure moments increased compared with last month.';
    }
    if (current.contradictionCount > prior.contradictionCount ||
        current.choiceCount > prior.choiceCount) {
      return 'More choice or challenge moments showed up compared with last month.';
    }
    if (current.restGuiltCount < prior.restGuiltCount) {
      return 'Rest guilt moments decreased compared with last month.';
    }
    return 'The mix of pressure, choice, and challenge moments stayed fairly similar.';
  }

  String _whatRepeated(_MonthStats current) {
    if (current.pressureExcerpts.isEmpty) {
      return 'Not enough pressure language to summarize yet.';
    }
    return current.pressureExcerpts.take(2).join('\n');
  }

  String _whatSeemedToCost(_MonthStats current) {
    if (current.restGuiltExcerpts.isNotEmpty) {
      return current.restGuiltExcerpts.take(2).join('\n');
    }
    if (current.pressureExcerpts.isNotEmpty &&
        current.pressureExcerpts.first.toLowerCase().contains('tired')) {
      return current.pressureExcerpts.first;
    }
    if (current.restGuiltCount > 0) {
      return 'Rest guilt appeared in ${current.restGuiltCount} moment(s).';
    }
    return 'Not enough rest-guilt language to summarize yet.';
  }

  String _choiceVsPressureSummary(_MonthStats current) {
    return 'Pressure: ${current.pressureCount} · Choice: ${current.choiceCount}';
  }

  String _restGuiltSummary(_MonthStats current) {
    if (current.restGuiltExcerpts.isEmpty) {
      return current.restGuiltCount == 0
          ? 'No clear rest-guilt language this month.'
          : 'Rest guilt appeared in ${current.restGuiltCount} moment(s).';
    }
    return current.restGuiltExcerpts.take(2).join('\n');
  }

  String _triggerSummary(
    LoopTriggerMapModel triggerMap,
    List<String> topTriggers,
  ) {
    if (topTriggers.isNotEmpty) return topTriggers.join('\n');
    if (!triggerMap.hasEnoughData) {
      return LoopTriggerMapModel.notEnoughDataCopy;
    }
    return 'No clear trigger pattern yet.';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[date.month - 1];
  }

  void _addExcerpt(List<String> target, String excerpt) {
    if (excerpt.isEmpty) return;
    if (target.contains(excerpt)) return;
    target.add(excerpt);
  }

  String _excerpt(String transcript) {
    final cleaned = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length < ArchiveEvidenceGuard.minimumTranscriptChars) return '';
    if (cleaned.length <= _excerptMaxChars) return cleaned;
    return '${cleaned.substring(0, _excerptMaxChars - 1).trim()}…';
  }
}

class _MonthStats {
  int totalProvingMoments = 0;
  int pressureCount = 0;
  int choiceCount = 0;
  int restGuiltCount = 0;
  int contradictionCount = 0;
  final List<String> pressureExcerpts = [];
  final List<String> choiceExcerpts = [];
  final List<String> restGuiltExcerpts = [];
  final List<String> contradictionExcerpts = [];

  double get pressureRatio =>
      totalProvingMoments == 0 ? 0 : pressureCount / totalProvingMoments;
}
