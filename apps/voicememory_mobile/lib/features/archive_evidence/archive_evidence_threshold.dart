import '../../models/journal_entry.dart';
import 'archive_belief_correction_store.dart';
import 'archive_entry_signal_guard.dart';
import 'archive_evidence_guard.dart';
import 'archive_evidence_heuristics.dart';

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
    return ArchiveEvidenceGuard.eligibleEntries(entries)
        .where((e) => !ArchiveEntrySignalGuard.isLowSignalEntry(e))
        .toList();
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
    final boosted = suggestionId != null &&
        suggestionId.isNotEmpty &&
        ArchiveBeliefCorrectionStore.isSaved(suggestionId);

    final meetsCoreThreshold = sharedThemeCount >= minSharedThemeEntries &&
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
        canNameThread: sharedThemeCount >= minSharedThemeEntries &&
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
    final changed = analysis.whatChangedLine?.trim().isNotEmpty == true &&
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
    if (meaningful.length >= 2) {
      final texts = meaningful.map((e) => e.transcript.toLowerCase()).toList();
      for (var i = 1; i < texts.length; i++) {
        if (_sharedTokenOverlap(texts[i - 1], texts[i]) >= 0.35) {
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
    if (analysis.repeatedPressurePhrases.isNotEmpty) {
      final phrase = analysis.repeatedPressurePhrases.first;
      final needle = phrase.split(' ').last;
      return meaningful
          .where((e) => e.transcript.toLowerCase().contains(needle))
          .length
          .clamp(0, meaningful.length);
    }

    final themes = meaningful
        .map((e) => _detectContext(e.transcript.toLowerCase()))
        .whereType<String>()
        .toList();
    if (themes.isEmpty) return 0;

    final counts = <String, int>{};
    for (final theme in themes) {
      counts[theme] = (counts[theme] ?? 0) + 1;
    }
    return counts.values.fold(0, (a, b) => a > b ? a : b);
  }

  static List<String> _collectSnippets(
    List<JournalEntry> meaningful,
    Iterable<String> attachedSnippets,
  ) {
    final snippets = <String>{};
    for (final raw in attachedSnippets) {
      final trimmed = raw.trim();
      if (trimmed.length >= minSnippetChars) snippets.add(trimmed);
    }
    for (final entry in meaningful.reversed) {
      final trimmed = entry.transcript.trim();
      if (trimmed.length >= minSnippetChars) {
        snippets.add(trimmed.length <= 96 ? trimmed : '${trimmed.substring(0, 95)}…');
      }
      if (snippets.length >= minEvidenceSnippets) break;
    }
    return snippets.toList();
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
