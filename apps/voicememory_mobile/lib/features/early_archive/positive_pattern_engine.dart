import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_repeat_phrase_sanitizer.dart';
import '../timeline/timeline_entry_display.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_first_signal_engine.dart';
import 'positive_pattern_copy.dart';
import 'positive_pattern_models.dart';

/// Detects repeated helpful actions grounded in the user's own words.
abstract final class PositivePatternEngine {
  PositivePatternEngine._();

  static const minEntryCount = 3;
  static const minEntriesPerCue = 2;
  static const maxEvidencePhrases = 3;
  static const minWords = 2;
  static const maxWords = 8;

  static const _bannedGenericPositivity = {
    'happy',
    'grateful',
    'gratitude',
    'positive',
    'better day',
    'good day',
    'great day',
    'feeling good',
    'feel good',
    'feeling better',
    'feel better',
    'amazing',
    'awesome',
    'blessed',
  };

  /// Action-oriented cues — must appear in user text, never invented.
  static const _helpfulCuePhrases = [
    'walked outside',
    'went for a walk',
    'walk outside',
    'went outside',
    'called someone',
    'called a friend',
    'called my',
    'started early',
    'started earlier',
    'wrote it down',
    'paused before replying',
    'paused before',
    'waited before',
    'asked for help',
    'reached out',
    'talked to',
    'made a plan',
    'took a break',
    'took a pause',
    'chose to wait',
    'decided to wait',
    'finished the task',
    'got it done',
    'went to bed early',
    'slept early',
  ];

  static PositivePatternResult? build({required List<JournalEntry> entries}) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < minEntryCount) return null;

    final texts = eligible.map(_entryText).where((t) => t.isNotEmpty).toList();
    if (texts.length < minEntryCount) return null;

    final repeatPhraseSet =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)
        ? ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases
              .map((phrase) => ArchiveRepeatPhraseSanitizer.sanitize(phrase))
              .where((phrase) => phrase.isNotEmpty)
              .toSet()
        : const <String>{};

    final cueEntryCounts = <String, Set<int>>{};
    for (var i = 0; i < texts.length; i++) {
      final lower = texts[i].toLowerCase();
      if (_containsBannedGeneric(lower)) continue;
      for (final cue in _helpfulCuePhrases) {
        if (!lower.contains(cue)) continue;
        cueEntryCounts.putIfAbsent(cue, () => <int>{}).add(i);
      }
    }

    final repeatedCues =
        cueEntryCounts.entries
            .where((entry) => entry.value.length >= minEntriesPerCue)
            .toList()
          ..sort((a, b) {
            final countCompare = b.value.length.compareTo(a.value.length);
            if (countCompare != 0) return countCompare;
            return b.key.length.compareTo(a.key.length);
          });

    if (repeatedCues.isEmpty) return null;

    final evidencePhrases = <String>[];
    for (final cueHit in repeatedCues) {
      final display = _displayFromEntries(texts, cueHit.key);
      if (display == null) continue;
      if (_overlapsRepeatEvidence(display, repeatPhraseSet)) continue;
      if (evidencePhrases.any(
        (phrase) =>
            phrase.toLowerCase() == display.toLowerCase() ||
            ArchiveRepeatPhraseSanitizer.sanitize(phrase) ==
                ArchiveRepeatPhraseSanitizer.sanitize(display),
      )) {
        continue;
      }
      evidencePhrases.add('"$display"');
      if (evidencePhrases.length >= maxEvidencePhrases) break;
    }

    if (evidencePhrases.isEmpty) return null;

    return PositivePatternResult(
      title: PositivePatternCopy.title,
      body: PositivePatternCopy.bodyWithPhrase(
        evidencePhrases.first.replaceAll('"', '').trim(),
      ),
      evidencePhrases: evidencePhrases,
    );
  }

  static bool _containsBannedGeneric(String lower) {
    for (final token in _bannedGenericPositivity) {
      if (lower.contains(token)) {
        final hasActionCue = _helpfulCuePhrases.any(lower.contains);
        if (!hasActionCue) return true;
      }
    }
    return false;
  }

  static bool _overlapsRepeatEvidence(
    String phrase,
    Set<String> repeatPhraseSet,
  ) {
    final normalized = ArchiveRepeatPhraseSanitizer.sanitize(phrase);
    if (normalized.isEmpty) return false;
    for (final repeat in repeatPhraseSet) {
      if (repeat.isEmpty) continue;
      if (normalized == repeat) return true;
      if (normalized.contains(repeat) || repeat.contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  static String? _displayFromEntries(List<String> texts, String cueLower) {
    final normalized = ArchiveRepeatPhraseSanitizer.sanitize(cueLower);
    if (normalized.isEmpty) return null;

    for (final text in texts) {
      final index = text.toLowerCase().indexOf(normalized);
      if (index < 0) continue;
      final end = index + normalized.length;
      if (end > text.length) continue;
      final slice = text.substring(index, end).trim();
      if (slice.isEmpty) continue;
      return slice;
    }
    return null;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }
}
