import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pattern_naming/pattern_name_engine.dart';
import 'archive_control_analytics.dart';
import 'archive_exclusion_store.dart';

/// Result of excluding one moment from one pattern's evidence.
class ArchivePatternExclusionResult {
  const ArchivePatternExclusionResult({
    required this.excluded,
    required this.entryCount,
    required this.hasConfirmedRepeat,
  });

  final bool excluded;
  final int entryCount;
  final bool hasConfirmedRepeat;
}

/// Stores and applies local pattern evidence exclusions.
abstract final class ArchiveExclusionEngine {
  ArchiveExclusionEngine._();

  static String normalizePatternKey(String groundedPhrase) =>
      PatternNameEngine.patternKey(groundedPhrase);

  static String? patternKeyFromGroundedPhrases(List<String> groundedPhrases) {
    final primary = groundedPhrases
        .map((phrase) => phrase.trim())
        .firstWhere((phrase) => phrase.isNotEmpty, orElse: () => '');
    if (primary.isEmpty) return null;
    return normalizePatternKey(primary);
  }

  static String? activePatternKeyForEntries(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return null;

    final confirmed = EarlyFirstSignalEngine.build(entries: entries);
    if (confirmed?.showsConfirmedRepeat == true &&
        confirmed!.evidencePhrases.isNotEmpty) {
      final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
        confirmed.evidencePhrases,
        eligible,
      );
      return patternKeyFromGroundedPhrases(grounded);
    }

    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(
      eligible.sublist(0, 3),
    );
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      evidence.phrases,
      eligible.sublist(0, 3),
    );
    return patternKeyFromGroundedPhrases(grounded);
  }

  static List<JournalEntry> eligibleForActivePattern(
    List<JournalEntry> entries,
  ) {
    final patternKey = activePatternKeyForEntries(entries);
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (patternKey == null) return eligible;
    return eligible
        .where(
          (entry) => !ArchiveExclusionStore.isExcluded(
            entryId: entry.id,
            patternKey: patternKey,
          ),
        )
        .toList();
  }

  static bool isExcludedForActivePattern({
    required String entryId,
    required List<JournalEntry> entries,
  }) {
    final patternKey = activePatternKeyForEntries(entries);
    if (patternKey == null) return false;
    return ArchiveExclusionStore.isExcluded(
      entryId: entryId,
      patternKey: patternKey,
    );
  }

  static Future<ArchivePatternExclusionResult> excludeFromPattern({
    required String entryId,
    required String patternKey,
    required String source,
  }) async {
    if (!AppServices.isInitialized) {
      return const ArchivePatternExclusionResult(
        excluded: false,
        entryCount: 0,
        hasConfirmedRepeat: false,
      );
    }

    await ArchiveExclusionStore.ensureLoaded();
    final normalizedKey = normalizePatternKey(patternKey);
    if (entryId.trim().isEmpty || normalizedKey.isEmpty) {
      final entries = await AppServices.instance.journal.loadAll();
      return ArchivePatternExclusionResult(
        excluded: false,
        entryCount: entries.length,
        hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          entries,
        ),
      );
    }

    await ArchiveExclusionStore.instance().exclude(
      entryId: entryId,
      patternKey: normalizedKey,
    );

    final entries = await AppServices.instance.journal.loadAll();
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    ArchiveControlAnalytics.patternEvidenceExcluded(
      source: source,
      entryCount: entries.length,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );

    return ArchivePatternExclusionResult(
      excluded: true,
      entryCount: entries.length,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }
}
