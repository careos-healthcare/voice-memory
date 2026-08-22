import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_entry_signal_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_pattern_copy_guard.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Safe, non-numeric stage labels for archive pattern surfaces.
enum ArchivePatternStage {
  stillForming,
  earlySignal,
  repeatedThread,
  strongPattern,
  changedRecently,
}

extension ArchivePatternStageCopy on ArchivePatternStage {
  String get label => switch (this) {
    ArchivePatternStage.stillForming => 'Still forming',
    ArchivePatternStage.earlySignal => 'Early signal',
    ArchivePatternStage.repeatedThread => 'Repeated thread',
    ArchivePatternStage.strongPattern => 'Strong pattern',
    ArchivePatternStage.changedRecently => 'Changed recently',
  };
}

/// Result of evaluating whether a thread/pattern may be named.
class ArchiveEvidenceThresholdResult {
  const ArchiveEvidenceThresholdResult({
    required this.canNameThread,
    required this.showFormingFallback,
    required this.stage,
    required this.meaningfulEntryCount,
    required this.sharedThemeEntryCount,
    required this.snippetCount,
    required this.hasRepeatedSignal,
    required this.suppressedByCorrection,
    required this.boostedByCorrection,
  });

  final bool canNameThread;
  final bool showFormingFallback;
  final ArchivePatternStage stage;
  final int meaningfulEntryCount;
  final int sharedThemeEntryCount;
  final int snippetCount;
  final bool hasRepeatedSignal;
  final bool suppressedByCorrection;
  final bool boostedByCorrection;

  static const forming = ArchiveEvidenceThresholdResult(
    canNameThread: false,
    showFormingFallback: true,
    stage: ArchivePatternStage.stillForming,
    meaningfulEntryCount: 0,
    sharedThemeEntryCount: 0,
    snippetCount: 0,
    hasRepeatedSignal: false,
    suppressedByCorrection: false,
    boostedByCorrection: false,
  );
}

/// Local thresholds before ArchiveMe names a belief or shows repeat claims.
abstract final class ArchiveEvidenceThreshold {
  ArchiveEvidenceThreshold._();

  static const minMeaningfulEntries = 3;
  static const minSharedThemeEntries = 2;
  static const minEvidenceSnippets = 2;
  static const minSnippetChars = 20;

  static const formingTitle = 'Your mind map is still forming';
  static const formingBody =
      'ArchiveMe needs more usable moments before it can name this thread.';

  static const _heuristics = ArchiveEvidenceHeuristics();

  /// Meaningful entries: eligible transcript, not degraded, not low-signal.
  static List<JournalEntry> meaningfulEntries(List<JournalEntry> entries) {
    return ArchiveEvidenceGuard.eligibleEntries(
      entries,
    ).where((e) => !ArchiveEntrySignalGuard.isLowSignalEntry(e)).toList();
  }

  static int meaningfulEntryCount(List<JournalEntry> entries) =>
      meaningfulEntries(entries).length;

  /// Evaluates whether evidence supports naming a thread or repeat claim.
  static ArchiveEvidenceThresholdResult evaluate(
    List<JournalEntry> entries, {
    String? suggestionId,
    ArchiveEvidenceAnalysis? analysis,
    Iterable<String> attachedSnippets = const [],
  }) {
    if (suggestionId != null &&
        suggestionId.isNotEmpty &&
        ArchiveBeliefCorrectionStore.isDismissed(suggestionId)) {
      return ArchiveEvidenceThresholdResult(
        canNameThread: false,
        showFormingFallback: true,
        stage: ArchivePatternStage.stillForming,
        meaningfulEntryCount: meaningfulEntryCount(entries),
        sharedThemeEntryCount: 0,
        snippetCount: 0,
        hasRepeatedSignal: false,
        suppressedByCorrection: true,
        boostedByCorrection: false,
      );
    }

    final meaningful = meaningfulEntries(entries);
    final count = meaningful.length;
    if (count < minMeaningfulEntries) {
      return ArchiveEvidenceThresholdResult(
        canNameThread: false,
        showFormingFallback: count > 0,
        stage: ArchivePatternStage.stillForming,
        meaningfulEntryCount: count,
        sharedThemeEntryCount: 0,
        snippetCount: 0,
        hasRepeatedSignal: false,
        suppressedByCorrection: false,
        boostedByCorrection: false,
      );
    }

    final resolvedAnalysis = analysis ?? _heuristics.analyze(entries);
    final sharedThemeCount = _sharedThemeEntryCount(
      meaningful,
      resolvedAnalysis,
    );
    final snippets = _collectSnippets(meaningful, attachedSnippets);
    final hasRepeated = _hasRepeatedSignal(resolvedAnalysis, meaningful);
    final boosted =
        suggestionId != null &&
        suggestionId.isNotEmpty &&
        ArchiveBeliefCorrectionStore.isSaved(suggestionId);

    final meetsCoreThreshold =
        sharedThemeCount >= minSharedThemeEntries &&
        snippets.length >= minEvidenceSnippets &&
        hasRepeated;

    if (!meetsCoreThreshold && !boosted) {
      return ArchiveEvidenceThresholdResult(
        canNameThread: false,
        showFormingFallback: true,
        stage: ArchivePatternStage.stillForming,
        meaningfulEntryCount: count,
        sharedThemeEntryCount: sharedThemeCount,
        snippetCount: snippets.length,
        hasRepeatedSignal: hasRepeated,
        suppressedByCorrection: false,
        boostedByCorrection: false,
      );
    }

    if (!meetsCoreThreshold && boosted) {
      return ArchiveEvidenceThresholdResult(
        canNameThread:
            sharedThemeCount >= minSharedThemeEntries &&
            snippets.length >= minEvidenceSnippets,
        showFormingFallback: false,
        stage: ArchivePatternStage.earlySignal,
        meaningfulEntryCount: count,
        sharedThemeEntryCount: sharedThemeCount,
        snippetCount: snippets.length,
        hasRepeatedSignal: hasRepeated,
        suppressedByCorrection: false,
        boostedByCorrection: true,
      );
    }

    final stage = _resolveStage(
      analysis: resolvedAnalysis,
      meaningfulCount: count,
      boosted: boosted,
    );

    return ArchiveEvidenceThresholdResult(
      canNameThread: true,
      showFormingFallback: false,
      stage: stage,
      meaningfulEntryCount: count,
      sharedThemeEntryCount: sharedThemeCount,
      snippetCount: snippets.length,
      hasRepeatedSignal: hasRepeated,
      suppressedByCorrection: false,
      boostedByCorrection: boosted,
    );
  }

  static ArchivePatternStage _resolveStage({
    required ArchiveEvidenceAnalysis analysis,
    required int meaningfulCount,
    required bool boosted,
  }) {
    final changed =
        analysis.whatChangedLine?.trim().isNotEmpty == true &&
        analysis.whatChangedLine !=
            'Your latest moment may sit differently from the one before it.';
    if (changed &&
        (analysis.whatChangedLine!.contains('noticed') ||
            analysis.whatChangedLine!.contains('earlier') ||
            analysis.whatChangedLine!.contains('Last time'))) {
      return ArchivePatternStage.changedRecently;
    }

    final band = analysis.confidenceBand;
    if (band == ArchiveConfidenceBand.strongerEvidence ||
        (meaningfulCount >= 5 &&
            analysis.repeatedPressurePhrases.length >= 2)) {
      return ArchivePatternStage.strongPattern;
    }
    if (band == ArchiveConfidenceBand.returningThread ||
        analysis.possibleRepeat) {
      return boosted
          ? ArchivePatternStage.strongPattern
          : ArchivePatternStage.repeatedThread;
    }
    if (boosted) return ArchivePatternStage.repeatedThread;
    return ArchivePatternStage.earlySignal;
  }

  static bool _hasRepeatedSignal(
    ArchiveEvidenceAnalysis analysis,
    List<JournalEntry> meaningful,
  ) {
    if (analysis.possibleRepeat) return true;
    if (analysis.repeatedPressurePhrases.length >= 2) return true;

    final texts = meaningful
        .map((e) => resolveEntryDisplayText(e).text.trim().toLowerCase())
        .where(
          (t) =>
              t.isNotEmpty && !ArchivePatternCopyGuard.isBlockedPatternText(t),
        )
        .toList();
    if (_entriesSharingRepeatSignal(texts) >= minSharedThemeEntries) {
      return true;
    }

    if (meaningful.length >= 2) {
      final rawTexts = meaningful
          .map((e) => e.transcript.toLowerCase())
          .toList();
      for (var i = 1; i < rawTexts.length; i++) {
        if (_sharedTokenOverlap(rawTexts[i - 1], rawTexts[i]) >= 0.35) {
          return true;
        }
      }
    }
    return false;
  }

  static int _sharedThemeEntryCount(
    List<JournalEntry> meaningful,
    ArchiveEvidenceAnalysis analysis,
  ) {
    final texts = meaningful
        .map((e) => resolveEntryDisplayText(e).text.trim().toLowerCase())
        .where(
          (t) =>
              t.isNotEmpty && !ArchivePatternCopyGuard.isBlockedPatternText(t),
        )
        .toList();
    if (texts.isEmpty) return 0;

    final themeCounts = <String, int>{};
    for (final text in texts) {
      final theme = _detectContext(text);
      if (theme != null) {
        themeCounts[theme] = (themeCounts[theme] ?? 0) + 1;
      }
    }
    final themeMax = themeCounts.values.fold(0, (a, b) => a > b ? a : b);

    final repeatMax = _entriesSharingRepeatSignal(texts);
    return [themeMax, repeatMax].reduce((a, b) => a > b ? a : b);
  }

  static int _entriesSharingRepeatSignal(List<String> texts) {
    if (texts.length < 2) return texts.length;

    final wordCounts = <String, int>{};
    for (final text in texts) {
      for (final word
          in text
              .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
              .split(RegExp(r'\s+'))
              .where((w) => w.length > 4)
              .toSet()) {
        wordCounts[word] = (wordCounts[word] ?? 0) + 1;
      }
    }

    final sharedWords =
        wordCounts.entries
            .where((e) => e.value >= minSharedThemeEntries)
            .map((e) => e.key)
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sharedWords) {
      final count = texts.where((t) => t.contains(word)).length;
      if (count >= minSharedThemeEntries) return count;
    }

    var bestCluster = 0;
    for (final anchor in texts) {
      final cluster = texts
          .where((other) => _sharedTokenOverlap(anchor, other) >= 0.25)
          .length;
      if (cluster > bestCluster) bestCluster = cluster;
    }
    return bestCluster;
  }

  static List<String> _collectSnippets(
    List<JournalEntry> meaningful,
    Iterable<String> attachedSnippets,
  ) {
    final snippets = <String>[];
    for (final raw in attachedSnippets) {
      final trimmed = raw.trim();
      if (trimmed.length < minSnippetChars) continue;
      if (ArchivePatternCopyGuard.isBlockedPatternText(trimmed)) continue;
      snippets.add(trimmed);
      if (snippets.length >= minEvidenceSnippets) break;
    }
    for (final entry in meaningful.reversed) {
      final trimmed = resolveEntryDisplayText(entry).text.trim();
      if (trimmed.length < minSnippetChars) continue;
      if (ArchivePatternCopyGuard.isBlockedPatternText(trimmed)) continue;
      snippets.add(
        trimmed.length <= 96 ? trimmed : '${trimmed.substring(0, 95)}…',
      );
      if (snippets.length >= minEvidenceSnippets) break;
    }
    return snippets;
  }

  static String? _detectContext(String text) {
    const keywords = {
      'work': ['work', 'office', 'deadline', 'boss', 'project', 'job'],
      'family': ['family', 'kids', 'child', 'partner', 'parent', 'home'],
      'rest': ['rest', 'tired', 'sleep', 'exhausted', 'burnout'],
      'saying yes': ['yes', 'agree', 'help', 'capacity', 'commit'],
      'deadlines': ['deadline', 'due', 'late', 'overdue'],
      'money': ['money', 'bills', 'rent', 'pay', 'afford'],
      'health': ['health', 'sick', 'doctor', 'pain'],
      'relationships': ['friend', 'relationship', 'people', 'partner'],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return null;
  }

  static double _sharedTokenOverlap(String a, String b) {
    final aTokens = a
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    final bTokens = b
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    return aTokens.intersection(bTokens).length / aTokens.union(bTokens).length;
  }
}