import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_hook_engine.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Maps saved voice moments into curiosity hook engine metadata.
abstract final class CuriosityHookMetadataExtractor {
  CuriosityHookMetadataExtractor._();

  static const _blockerPatterns = [
    'no capacity',
    'paused before',
    'got in the way',
    'could not',
    "couldn't",
    'avoided',
    'resisted',
    'blocked',
    'stuck',
    'overwhelmed',
  ];

  static CuriosityHookEntryMetadata fromEntry({
    required JournalEntry entry,
    required List<JournalEntry> allEntries,
  }) {
    return CuriosityHookEntryMetadata(
      entryId: entry.id,
      createdAt: entry.createdAt,
      extractedAnchors: _extractAnchors(entry: entry, allEntries: allEntries),
      emotionalTone: _emotionalTone(entry),
      hasBlockers: _hasBlockers(entry),
      entryCount: allEntries.length,
    );
  }

  static List<String> _extractAnchors({
    required JournalEntry entry,
    required List<JournalEntry> allEntries,
  }) {
    final anchors = <String>[];
    final eligible = ArchiveEvidenceGuard.eligibleEntries(allEntries);
    if (eligible.length >= 2) {
      final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
      anchors.addAll(
        ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
          evidence.phrases,
          eligible,
        ),
      );
    }

    for (final candidate in [
      ComparableEvidenceText.userText(entry),
      entry.reflection.exactLanguagePattern,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
    ]) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) continue;
      if (anchors.contains(trimmed)) continue;
      anchors.add(trimmed);
    }

    return anchors;
  }

  static String? _emotionalTone(JournalEntry entry) {
    final mood = entry.reflection.mood.trim();
    if (mood.isEmpty) return null;
    if (entry.reflection.emotionalIntensity >= 3) {
      return '$mood intense';
    }
    if (entry.reflection.emotionalIntensity <= 1) {
      return '$mood lighter';
    }
    return mood;
  }

  static bool _hasBlockers(JournalEntry entry) {
    final haystack = [
      ComparableEvidenceText.userText(entry),
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      entry.reflection.tensionOrContradiction ?? '',
      entry.reflection.avoidedOrVagueArea ?? '',
    ].join(' ').toLowerCase();

    if (haystack.trim().isEmpty) return false;
    return _blockerPatterns.any(haystack.contains);
  }
}