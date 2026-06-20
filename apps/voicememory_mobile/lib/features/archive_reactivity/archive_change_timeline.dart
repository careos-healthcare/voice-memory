import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../../models/journal_entry.dart';
import '../app_review/archive_app_review_access_gate.dart';
import 'archive_daily_pattern_check_in.dart';
import 'archive_display_copy_guard.dart';
import 'archive_emerging_pattern_radar.dart';
import 'archive_loop_experiment.dart';
import 'archive_personal_pattern_manual.dart';
import 'archive_positive_pattern_detector.dart';
import 'archive_return_value_proof.dart';
import 'archive_thought_map.dart';

enum ArchiveChangeTimelineItemSource {
  recording,
  thoughtMap,
  returnProof,
  returnResult,
  loopExperiment,
  loopExperimentResult,
  dailyCheckIn,
  positiveSignal,
  personalManual;

  String get logId => name;
}

enum ArchiveChangeTimelineItemType {
  loopFirstSeen,
  loopRepeated,
  urgencyIncreased,
  urgencySoftened,
  triggerRepeated,
  helpfulActionAppeared,
  experimentStarted,
  experimentHelped,
  experimentPartlyHelped,
  experimentDidNotHelp,
  loopShifted,
  unclearSignal;

  String get logId => name;
}

class ArchiveChangeTimelineItem {
  const ArchiveChangeTimelineItem({
    required this.id,
    required this.createdAt,
    this.entryId,
    required this.source,
    required this.type,
    required this.title,
    required this.evidenceLine,
    required this.changeLine,
    required this.nextLine,
    required this.confidenceLabel,
    required this.evidenceEntryIds,
  });

  final String id;
  final DateTime createdAt;
  final String? entryId;
  final ArchiveChangeTimelineItemSource source;
  final ArchiveChangeTimelineItemType type;
  final String title;
  final String evidenceLine;
  final String changeLine;
  final String nextLine;
  final String confidenceLabel;
  final List<String> evidenceEntryIds;

  bool get hasRecordPrompt => nextLine.trim().isNotEmpty;
}

class ArchiveChangeTimeline {
  const ArchiveChangeTimeline({
    required this.generatedAt,
    this.patternKey,
    required this.title,
    required this.summaryLine,
    required this.timelineItems,
    this.strongestChange,
    this.helpfulChange,
    this.nextBestPrompt,
    required this.confidenceLabel,
    required this.sourceEntryIds,
    required this.needsMoreEvidence,
    required this.hasExperimentResult,
  });

  final DateTime generatedAt;
  final String? patternKey;
  final String title;
  final String summaryLine;
  final List<ArchiveChangeTimelineItem> timelineItems;
  final ArchiveChangeTimelineItem? strongestChange;
  final ArchiveChangeTimelineItem? helpfulChange;
  final String? nextBestPrompt;
  final String confidenceLabel;
  final List<String> sourceEntryIds;
  final bool needsMoreEvidence;
  final bool hasExperimentResult;

  bool get shouldDisplay =>
      summaryLine.trim().isNotEmpty &&
      timelineItems.isNotEmpty &&
      (timelineItems.length >= 2 ||
          (needsMoreEvidence && timelineItems.length == 1));

  bool get hasMeaningfulItems => timelineItems.length >= 2;

  bool get hasHelpfulChange => helpfulChange != null;

  bool get hasSofteningChange => timelineItems.any(
        (item) =>
            item.type == ArchiveChangeTimelineItemType.urgencySoftened ||
            item.type == ArchiveChangeTimelineItemType.experimentHelped,
      );
}

abstract class ArchiveChangeTimelineCopy {
  ArchiveChangeTimelineCopy._();

  static const cardTitle = 'Change timeline';
  static const cardSubtitle = 'How this pattern is moving over time';
  static const recordThisNextCta = 'Record this next';
  static const recordThisNextPrefix = 'Record this next:';
}

abstract class ArchiveChangeTimelineLog {
  ArchiveChangeTimelineLog._();

  static void resolved({
    required int items,
    required String confidence,
  }) {
    debugPrint(
      'ARCHIVEME_CHANGE_TIMELINE_RESOLVED items=$items confidence=$confidence',
    );
  }

  static void item({
    required ArchiveChangeTimelineItemType type,
    required String confidence,
  }) {
    debugPrint(
      'ARCHIVEME_CHANGE_TIMELINE_ITEM type=${type.logId} confidence=$confidence',
    );
  }

  static void shown({required String surface}) {
    debugPrint('ARCHIVEME_CHANGE_TIMELINE_SHOWN surface=$surface');
  }

  static void promptTapped({required ArchiveChangeTimelineItemType type}) {
    debugPrint(
      'ARCHIVEME_CHANGE_TIMELINE_PROMPT_TAPPED type=${type.logId}',
    );
  }
}

abstract class ArchiveChangeTimelinePlacement {
  ArchiveChangeTimelinePlacement._();

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
    defaultValue: false,
  );

  @visibleForTesting
  static bool? blockForTest;

  static bool isEnvironmentBlocked() {
    if (blockForTest != null) return blockForTest!;
    if (ArchiveAppReviewAccessGate.isEnabled) return true;
    return false;
  }

  static bool shouldShow({
    required int entryCount,
    required bool firstValueRescueActive,
    required ArchiveChangeTimeline? timeline,
    required bool hasFullMap,
    required ArchiveEmergingPatternRadar? radar,
    required ArchivePersonalPatternManual? manual,
  }) {
    if (isEnvironmentBlocked()) return false;
    if (entryCount < 1) return false;
    if (firstValueRescueActive) return false;
    if (timeline == null || !timeline.shouldDisplay) return false;
    if (!hasFullMap && entryCount < 3) return false;
    if (repeatsOtherSurfaceCopy(
      timeline: timeline,
      radar: radar,
      manual: manual,
    )) {
      return false;
    }
    return true;
  }

  static bool shouldPlaceAboveManual({
    required ArchiveChangeTimeline timeline,
    required ArchivePersonalPatternManual? manual,
    required bool hasCompletedExperiment,
  }) {
    if (manual == null || !manual.hasMeaningfulSections) return true;
    if (hasCompletedExperiment) return true;
    if (manual.sections.length >= 4) return false;
    return timeline.hasMeaningfulItems;
  }

  static bool repeatsOtherSurfaceCopy({
    required ArchiveChangeTimeline timeline,
    required ArchiveEmergingPatternRadar? radar,
    required ArchivePersonalPatternManual? manual,
  }) {
    final summary = timeline.summaryLine.trim().toLowerCase();
    if (summary.isEmpty) return true;
    if (radar != null &&
        radar.summaryLine.trim().toLowerCase() == summary &&
        timeline.timelineItems.length <= 2) {
      return true;
    }
    if (manual != null &&
        manual.summaryLine.trim().toLowerCase() == summary) {
      return true;
    }
    return false;
  }
}

abstract class ArchiveChangeTimelineResolver {
  ArchiveChangeTimelineResolver._();

  static const _maxItems = 7;

  static const _banned = [
    'therapy',
    'diagnosis',
    'treatment',
    'cure',
    'mental health',
    'fix your thoughts',
    'negative thoughts',
    'bad behaviour',
    'addictive',
    'you always',
    'this proves',
    'coach',
  ];

  static const _checkingPhrases = [
    'checking again',
    'check again',
    'keep checking',
    'again and again',
    'need to check',
    'had to check',
    'verify again',
  ];

  static const _urgencyMarkers = [
    'urgent',
    'worried',
    'must',
    'have to',
    'can\'t stop',
    'need',
    'again',
    'keep',
  ];

  static const _softenedMarkers = [
    'less urgent',
    'easier to stop',
    'calmer',
    'softer',
    'paused',
    'waited',
    'stopped sooner',
  ];

  static ArchiveChangeTimeline? resolve({
    required List<JournalEntry> entries,
    required ArchiveThoughtMap? thoughtMap,
    required ArchiveEmergingPatternRadar? radar,
    required ArchiveReturnValueProofResult? latestReturnResult,
    required ArchiveLoopExperiment? latestExperiment,
    required ArchiveLoopExperimentResult? latestExperimentResult,
    required ArchiveDailyPatternCheckIn? latestDailyCheckIn,
    required ArchiveDailyPatternCheckInResult? latestDailyCheckInResult,
    required ArchivePersonalPatternManual? manual,
    required List<ArchivePositivePatternSignal> positiveSignals,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final usable = entries
        .where((entry) => entry.transcript.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (usable.isEmpty) return null;

    final items = <ArchiveChangeTimelineItem>[];
    final sourceEntryIds = <String>[];

    final firstLoopEntry = _firstLoopEvidenceEntry(usable, thoughtMap);
    if (firstLoopEntry != null) {
      final item = _loopFirstSeen(
        entry: firstLoopEntry,
        thoughtMap: thoughtMap,
        clock: clock,
      );
      if (item != null) items.add(item);
    }

    final repeatedEntry = _repeatedLoopEntry(usable, firstLoopEntry);
    if (repeatedEntry != null) {
      final item = _loopRepeated(entry: repeatedEntry, clock: clock);
      if (item != null) items.add(item);
    }

    final urgencyIncreased = _urgencyIncreasedItem(usable, clock: clock);
    if (urgencyIncreased != null) items.add(urgencyIncreased);

    final urgencySoftened = _urgencySoftenedItem(
      entries: usable,
      returnResult: latestReturnResult,
      clock: clock,
    );
    if (urgencySoftened != null) items.add(urgencySoftened);

    if (positiveSignals.isNotEmpty) {
      final item = _helpfulAction(
        signal: positiveSignals.first,
        clock: clock,
      );
      if (item != null) items.add(item);
    }

    if (latestExperiment != null &&
        (latestExperiment.isAccepted || latestExperiment.isCompleted)) {
      final item = _experimentStarted(
        experiment: latestExperiment,
        clock: clock,
      );
      if (item != null) items.add(item);
    }

    if (latestExperiment != null &&
        latestExperiment.isCompleted &&
        latestExperimentResult != null) {
      final item = _experimentResult(
        experiment: latestExperiment,
        result: latestExperimentResult,
        clock: clock,
      );
      if (item != null) items.add(item);
    }

    if (latestReturnResult != null) {
      final item = _fromReturnResult(
        result: latestReturnResult,
        entries: usable,
        clock: clock,
      );
      if (item != null) items.add(item);
    }

    if (latestDailyCheckIn != null &&
        latestDailyCheckIn.isCompleted &&
        latestDailyCheckInResult != null) {
      final item = _fromDailyCheckInResult(
        checkIn: latestDailyCheckIn,
        result: latestDailyCheckInResult,
        clock: clock,
      );
      if (item != null) items.add(item);
    }

    final deduped = _dedupeItems(items);
    deduped.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final capped = deduped.take(_maxItems).toList();

    for (final item in capped) {
      sourceEntryIds.addAll(item.evidenceEntryIds);
      ArchiveChangeTimelineLog.item(
        type: item.type,
        confidence: item.confidenceLabel,
      );
    }

    final needsMoreEvidence = capped.length < 2;
    if (needsMoreEvidence && capped.isEmpty) return null;

    final strongestChange = _strongestChange(capped);
    final helpfulChange = _helpfulChange(capped);
    final summaryLine = _summaryLine(
      items: capped,
      thoughtMap: thoughtMap,
      needsMoreEvidence: needsMoreEvidence,
    );
    if (summaryLine.isEmpty) return null;

    final timeline = ArchiveChangeTimeline(
      generatedAt: clock,
      patternKey: thoughtMap?.mapId ?? latestExperiment?.patternKey,
      title: ArchiveChangeTimelineCopy.cardTitle,
      summaryLine: summaryLine,
      timelineItems: capped,
      strongestChange: strongestChange,
      helpfulChange: helpfulChange,
      nextBestPrompt: _nextBestPrompt(capped),
      confidenceLabel: thoughtMap?.confidenceLabel.trim().isNotEmpty == true
          ? thoughtMap!.confidenceLabel
          : 'Based on your words',
      sourceEntryIds: sourceEntryIds.toSet().toList(),
      needsMoreEvidence: needsMoreEvidence,
      hasExperimentResult: capped.any(
        (item) =>
            item.type == ArchiveChangeTimelineItemType.experimentHelped ||
            item.type == ArchiveChangeTimelineItemType.experimentPartlyHelped ||
            item.type == ArchiveChangeTimelineItemType.experimentDidNotHelp,
      ),
    );

    ArchiveChangeTimelineLog.resolved(
      items: timeline.timelineItems.length,
      confidence: timeline.confidenceLabel,
    );
    return timeline;
  }

  static String recordRouteFor(ArchiveChangeTimelineItem item) {
    final prompt = item.nextLine.trim().isNotEmpty
        ? item.nextLine
        : 'Record the next time this appears.';
    final params = <String, String>{
      'guidedPromptText': prompt,
      'guidedPromptId': item.id,
      'guidedPromptNodeKey': 'changeTimeline',
      'prompt': prompt,
    };
    return Uri(path: '/record', queryParameters: params).toString();
  }

  static JournalEntry? _firstLoopEvidenceEntry(
    List<JournalEntry> entries,
    ArchiveThoughtMap? thoughtMap,
  ) {
    for (final entry in entries) {
      if (_hasLoopLanguage(entry.transcript)) return entry;
    }
    if (thoughtMap != null && entries.isNotEmpty) {
      return entries.first;
    }
    return null;
  }

  static JournalEntry? _repeatedLoopEntry(
    List<JournalEntry> entries,
    JournalEntry? first,
  ) {
    if (first == null) return null;
    for (final entry in entries) {
      if (entry.id == first.id) continue;
      if (_hasLoopLanguage(entry.transcript)) return entry;
    }
    return null;
  }

  static bool _hasLoopLanguage(String transcript) {
    final lower = transcript.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return _checkingPhrases.any(lower.contains);
  }

  static int _urgencyScore(String transcript) {
    final lower = transcript.toLowerCase();
    return _urgencyMarkers.where(lower.contains).length;
  }

  static ArchiveChangeTimelineItem? _loopFirstSeen({
    required JournalEntry entry,
    required ArchiveThoughtMap? thoughtMap,
    required DateTime clock,
  }) {
    final quote = thoughtMap?.strongestQuote.trim() ?? '';
    final evidence = quote.isNotEmpty
        ? "The strongest clue was: '$quote'."
        : _quoteFromEntry(entry);
    return _buildItem(
      idSuffix: 'first_seen',
      createdAt: entry.createdAt,
      entryId: entry.id,
      source: thoughtMap != null
          ? ArchiveChangeTimelineItemSource.thoughtMap
          : ArchiveChangeTimelineItemSource.recording,
      type: ArchiveChangeTimelineItemType.loopFirstSeen,
      title: 'Loop first noticed',
      evidenceLine: evidence,
      changeLine:
          'ArchiveMe started watching whether this was about the result, relief, or both.',
      nextLine: 'Record the next time this appears.',
      confidenceLabel: thoughtMap?.confidenceLabel.trim().isNotEmpty == true
          ? thoughtMap!.confidenceLabel
          : 'Early signal',
      evidenceEntryIds: [entry.id],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _loopRepeated({
    required JournalEntry entry,
    required DateTime clock,
  }) {
    return _buildItem(
      idSuffix: 'repeated',
      createdAt: entry.createdAt,
      entryId: entry.id,
      source: ArchiveChangeTimelineItemSource.recording,
      type: ArchiveChangeTimelineItemType.loopRepeated,
      title: 'The loop came back',
      evidenceLine: 'Checking appeared again in a later recording.',
      changeLine: 'This is no longer just one moment.',
      nextLine: 'Watch what happens before the second check.',
      confidenceLabel: 'Based on your words',
      evidenceEntryIds: [entry.id],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _urgencyIncreasedItem(
    List<JournalEntry> entries, {
    required DateTime clock,
  }) {
    if (entries.length < 2) return null;
    final first = entries.first;
    final latest = entries.last;
    if (first.id == latest.id) return null;
    final firstScore = _urgencyScore(first.transcript);
    final latestScore = _urgencyScore(latest.transcript);
    if (latestScore <= firstScore || latestScore < 2) return null;
    return _buildItem(
      idSuffix: 'urgency_up',
      createdAt: latest.createdAt,
      entryId: latest.id,
      source: ArchiveChangeTimelineItemSource.recording,
      type: ArchiveChangeTimelineItemType.urgencyIncreased,
      title: 'This got louder',
      evidenceLine: 'The latest recording added more urgency.',
      changeLine: 'The loop may be asking for relief, not only a result.',
      nextLine: 'Record whether one useful check is enough.',
      confidenceLabel: 'Early signal',
      evidenceEntryIds: [latest.id],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _urgencySoftenedItem({
    required List<JournalEntry> entries,
    required ArchiveReturnValueProofResult? returnResult,
    required DateTime clock,
  }) {
    if (returnResult?.resultType ==
        ArchiveReturnValueProofResultType.softened) {
      return _buildItem(
        idSuffix: 'softened_return',
        createdAt: entries.last.createdAt,
        entryId: entries.last.id,
        source: ArchiveChangeTimelineItemSource.returnResult,
        type: ArchiveChangeTimelineItemType.urgencySoftened,
        title: 'This softened',
        evidenceLine: returnResult!.evidenceLine.trim().isNotEmpty
            ? returnResult.evidenceLine
            : 'Your latest recording sounded less urgent.',
        changeLine: 'ArchiveMe should watch whether this change lasts.',
        nextLine: 'Record the next time it appears.',
        confidenceLabel: returnResult.confidenceLabel,
        evidenceEntryIds: [entries.last.id],
        clock: clock,
      );
    }
    if (entries.length < 2) return null;
    final latest = entries.last;
    final lower = latest.transcript.toLowerCase();
    if (!_softenedMarkers.any(lower.contains)) return null;
    final earlier = entries.sublist(0, entries.length - 1);
    final hadUrgency = earlier.any(
      (entry) => _urgencyScore(entry.transcript) >= 2,
    );
    if (!hadUrgency) return null;
    return _buildItem(
      idSuffix: 'softened_language',
      createdAt: latest.createdAt,
      entryId: latest.id,
      source: ArchiveChangeTimelineItemSource.recording,
      type: ArchiveChangeTimelineItemType.urgencySoftened,
      title: 'This softened',
      evidenceLine: 'Your latest recording sounded less urgent.',
      changeLine: 'ArchiveMe should watch whether this change lasts.',
      nextLine: 'Record the next time it appears.',
      confidenceLabel: 'Early signal',
      evidenceEntryIds: [latest.id],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _helpfulAction({
    required ArchivePositivePatternSignal signal,
    required DateTime clock,
  }) {
    return _buildItem(
      idSuffix: 'helpful_${signal.entryId}',
      createdAt: clock,
      entryId: signal.entryId,
      source: ArchiveChangeTimelineItemSource.positiveSignal,
      type: ArchiveChangeTimelineItemType.helpfulActionAppeared,
      title: 'Something helped',
      evidenceLine:
          "Your recording mentioned waiting, pausing, or stopping sooner.",
      changeLine: 'This may be worth repeating.',
      nextLine: 'Record what made the pause possible.',
      confidenceLabel: signal.confidenceLabel,
      evidenceEntryIds: [signal.entryId],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _experimentStarted({
    required ArchiveLoopExperiment experiment,
    required DateTime clock,
  }) {
    return _buildItem(
      idSuffix: 'experiment_start_${experiment.id}',
      createdAt: experiment.acceptedAt ?? experiment.createdAt,
      entryId: experiment.completedEntryId,
      source: ArchiveChangeTimelineItemSource.loopExperiment,
      type: ArchiveChangeTimelineItemType.experimentStarted,
      title: 'A small test started',
      evidenceLine: experiment.whyThisExperimentLine,
      changeLine: 'ArchiveMe is watching what changes from this test.',
      nextLine: experiment.recordingPrompt,
      confidenceLabel: experiment.expectedSignal.logId,
      evidenceEntryIds: experiment.createdFromEvidenceEntryIds,
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _experimentResult({
    required ArchiveLoopExperiment experiment,
    required ArchiveLoopExperimentResult result,
    required DateTime clock,
  }) {
    final type = switch (result.resultType) {
      ArchiveLoopExperimentResultType.helped ||
      ArchiveLoopExperimentResultType.positiveRepeat ||
      ArchiveLoopExperimentResultType.loopSoftened =>
        ArchiveChangeTimelineItemType.experimentHelped,
      ArchiveLoopExperimentResultType.partlyHelped =>
        ArchiveChangeTimelineItemType.experimentPartlyHelped,
      ArchiveLoopExperimentResultType.didNotHelp =>
        ArchiveChangeTimelineItemType.experimentDidNotHelp,
      ArchiveLoopExperimentResultType.loopShifted =>
        ArchiveChangeTimelineItemType.loopShifted,
      ArchiveLoopExperimentResultType.unclear =>
        ArchiveChangeTimelineItemType.unclearSignal,
    };
    final title = switch (type) {
      ArchiveChangeTimelineItemType.experimentHelped =>
        'A test seemed to help',
      ArchiveChangeTimelineItemType.experimentPartlyHelped =>
        'A test partly helped',
      ArchiveChangeTimelineItemType.experimentDidNotHelp =>
        'A test did not help yet',
      ArchiveChangeTimelineItemType.loopShifted => 'The loop shifted',
      _ => 'Test result saved',
    };
    final changeLine = switch (type) {
      ArchiveChangeTimelineItemType.experimentHelped =>
        'This is a signal to test again, not proof yet.',
      ArchiveChangeTimelineItemType.experimentPartlyHelped =>
        'ArchiveMe should watch whether this holds on the next return.',
      ArchiveChangeTimelineItemType.experimentDidNotHelp =>
        'One test may not be enough to read this loop yet.',
      _ => 'ArchiveMe should watch what changes on the next return.',
    };
    final nextLine = result.nextExperimentLine.trim().isNotEmpty
        ? result.nextExperimentLine
        : 'Repeat the small test once more.';
    return _buildItem(
      idSuffix: 'experiment_result_${experiment.id}',
      createdAt: experiment.completedAt ?? clock,
      entryId: experiment.completedEntryId,
      source: ArchiveChangeTimelineItemSource.loopExperimentResult,
      type: type,
      title: title,
      evidenceLine: result.evidenceLine,
      changeLine: changeLine,
      nextLine: nextLine,
      confidenceLabel: result.confidenceLabel,
      evidenceEntryIds: [
        if (experiment.completedEntryId != null) experiment.completedEntryId!,
        ...experiment.createdFromEvidenceEntryIds,
      ],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _fromReturnResult({
    required ArchiveReturnValueProofResult result,
    required List<JournalEntry> entries,
    required DateTime clock,
  }) {
    final type = switch (result.resultType) {
      ArchiveReturnValueProofResultType.repeated =>
        ArchiveChangeTimelineItemType.loopRepeated,
      ArchiveReturnValueProofResultType.softened =>
        ArchiveChangeTimelineItemType.urgencySoftened,
      ArchiveReturnValueProofResultType.shifted =>
        ArchiveChangeTimelineItemType.loopShifted,
      ArchiveReturnValueProofResultType.didNotReturn =>
        ArchiveChangeTimelineItemType.helpfulActionAppeared,
      ArchiveReturnValueProofResultType.unclear =>
        ArchiveChangeTimelineItemType.unclearSignal,
    };
    if (type == ArchiveChangeTimelineItemType.urgencySoftened) {
      return null;
    }
    final title = result.title.trim().isNotEmpty
        ? result.title
        : switch (type) {
            ArchiveChangeTimelineItemType.loopRepeated =>
              'The loop came back',
            ArchiveChangeTimelineItemType.loopShifted =>
              'The loop changed shape',
            _ => 'Return recorded',
          };
    return _buildItem(
      idSuffix: 'return_${result.resultType.logId}',
      createdAt: entries.last.createdAt,
      entryId: entries.last.id,
      source: ArchiveChangeTimelineItemSource.returnResult,
      type: type,
      title: title,
      evidenceLine: result.evidenceLine,
      changeLine: result.comparisonLine,
      nextLine: result.nextStepLine,
      confidenceLabel: result.confidenceLabel,
      evidenceEntryIds: [entries.last.id],
      clock: clock,
    );
  }

  static ArchiveChangeTimelineItem? _fromDailyCheckInResult({
    required ArchiveDailyPatternCheckIn checkIn,
    required ArchiveDailyPatternCheckInResult result,
    required DateTime clock,
  }) {
    final type = switch (result.resultType) {
      ArchiveDailyPatternCheckInResultType.helpfulSignalFound =>
        ArchiveChangeTimelineItemType.helpfulActionAppeared,
      ArchiveDailyPatternCheckInResultType.loopSignalFound =>
        ArchiveChangeTimelineItemType.loopRepeated,
      _ => ArchiveChangeTimelineItemType.unclearSignal,
    };
    return _buildItem(
      idSuffix: 'daily_${checkIn.id}',
      createdAt: checkIn.completedAt ?? clock,
      entryId: checkIn.completedEntryId,
      source: ArchiveChangeTimelineItemSource.dailyCheckIn,
      type: type,
      title: result.title,
      evidenceLine: result.evidenceLine,
      changeLine: result.nextLine,
      nextLine: checkIn.recordingPrompt,
      confidenceLabel: result.confidenceLabel,
      evidenceEntryIds: [
        if (checkIn.completedEntryId != null) checkIn.completedEntryId!,
      ],
      clock: clock,
    );
  }

  static List<ArchiveChangeTimelineItem> _dedupeItems(
    List<ArchiveChangeTimelineItem> items,
  ) {
    final seen = <ArchiveChangeTimelineItemType>{};
    final output = <ArchiveChangeTimelineItem>[];
    for (final item in items) {
      if (item.type == ArchiveChangeTimelineItemType.unclearSignal) continue;
      if (seen.contains(item.type)) continue;
      seen.add(item.type);
      output.add(item);
    }
    return output;
  }

  static ArchiveChangeTimelineItem? _strongestChange(
    List<ArchiveChangeTimelineItem> items,
  ) {
    const priority = [
      ArchiveChangeTimelineItemType.experimentHelped,
      ArchiveChangeTimelineItemType.urgencySoftened,
      ArchiveChangeTimelineItemType.loopRepeated,
      ArchiveChangeTimelineItemType.urgencyIncreased,
      ArchiveChangeTimelineItemType.loopFirstSeen,
    ];
    for (final type in priority) {
      for (final item in items) {
        if (item.type == type) return item;
      }
    }
    return items.isNotEmpty ? items.last : null;
  }

  static ArchiveChangeTimelineItem? _helpfulChange(
    List<ArchiveChangeTimelineItem> items,
  ) {
    for (final item in items) {
      if (item.type == ArchiveChangeTimelineItemType.helpfulActionAppeared ||
          item.type == ArchiveChangeTimelineItemType.experimentHelped ||
          item.type == ArchiveChangeTimelineItemType.urgencySoftened) {
        return item;
      }
    }
    return null;
  }

  static String _summaryLine({
    required List<ArchiveChangeTimelineItem> items,
    required ArchiveThoughtMap? thoughtMap,
    required bool needsMoreEvidence,
  }) {
    if (items.isEmpty) return '';
    if (needsMoreEvidence) {
      return 'ArchiveMe has one early signal so far. One more focused recording may show how this pattern moves.';
    }
    final hasSoftened = items.any(
      (item) => item.type == ArchiveChangeTimelineItemType.urgencySoftened,
    );
    final hasRepeated = items.any(
      (item) => item.type == ArchiveChangeTimelineItemType.loopRepeated,
    );
    final hasHelpful = items.any(
      (item) =>
          item.type == ArchiveChangeTimelineItemType.helpfulActionAppeared ||
          item.type == ArchiveChangeTimelineItemType.experimentHelped,
    );
    if (hasSoftened && hasRepeated) {
      return 'Your recordings suggest this loop came back, then softened on a later return.';
    }
    if (hasHelpful && hasRepeated) {
      return 'Your recordings suggest the loop repeated, but a helpful action also appeared.';
    }
    if (hasRepeated) {
      return 'Your recordings suggest this loop is repeating across more than one moment.';
    }
    if (thoughtMap != null && thoughtMap.hasEnoughEvidence) {
      return 'ArchiveMe is watching how this loop changes from your saved map and later recordings.';
    }
    return 'Your recordings suggest one thread is starting to show a pattern over time.';
  }

  static String? _nextBestPrompt(List<ArchiveChangeTimelineItem> items) {
    for (final item in items.reversed) {
      if (item.hasRecordPrompt) return item.nextLine;
    }
    return null;
  }

  static String _quoteFromEntry(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.length <= 80) {
      return "The strongest clue was: '$transcript'.";
    }
    final snippet = transcript.substring(0, 80).trim();
    return "The strongest clue was: '$snippet'.";
  }

  static ArchiveChangeTimelineItem? _buildItem({
    required String idSuffix,
    required DateTime createdAt,
    required String? entryId,
    required ArchiveChangeTimelineItemSource source,
    required ArchiveChangeTimelineItemType type,
    required String title,
    required String evidenceLine,
    required String changeLine,
    required String nextLine,
    required String confidenceLabel,
    required List<String> evidenceEntryIds,
    required DateTime clock,
  }) {
    if (_containsBanned([
      title,
      evidenceLine,
      changeLine,
      nextLine,
    ])) {
      return null;
    }
    final guardedTitle = _guard(title, allowShortLabel: true);
    final guardedEvidence = _guard(evidenceLine);
    final guardedChange = _guard(changeLine);
    final guardedNext = _guard(nextLine);
    if ([guardedTitle, guardedEvidence, guardedChange].any(
      (value) => value.isEmpty,
    )) {
      return null;
    }
    return ArchiveChangeTimelineItem(
      id: 'acti_${idSuffix}_${clock.microsecondsSinceEpoch}',
      createdAt: createdAt,
      entryId: entryId,
      source: source,
      type: type,
      title: guardedTitle,
      evidenceLine: guardedEvidence,
      changeLine: guardedChange,
      nextLine: guardedNext,
      confidenceLabel: confidenceLabel.trim().isNotEmpty
          ? confidenceLabel
          : 'Based on your words',
      evidenceEntryIds: evidenceEntryIds,
    );
  }

  static String _guard(String raw, {bool allowShortLabel = false}) {
    return ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'evidence',
      text: raw,
      allowShortLabel: allowShortLabel,
      requireSpecificity: false,
    );
  }

  static bool _containsBanned(List<String> values) {
    final blob = values.join(' ').toLowerCase();
    return _banned.any(blob.contains);
  }
}
