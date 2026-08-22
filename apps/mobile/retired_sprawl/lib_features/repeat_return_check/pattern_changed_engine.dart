import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

enum PatternChangedType {
  changed;

  String get analyticsValue => name;

  bool get isCelebration => true;
}

/// Built pattern-changed card from repeat return check evidence.
class PatternChangedResult {
  const PatternChangedResult({
    required this.type,
    required this.title,
    required this.body,
    required this.footer,
    required this.entryId,
    required this.isCelebration,
    required this.usesPhraseEvidence,
    this.earlierPhrase,
    this.thisTimePhrase,
  });

  final PatternChangedType type;
  final String title;
  final String body;
  final String footer;
  final String entryId;
  final bool isCelebration;
  final bool usesPhraseEvidence;
  final String? earlierPhrase;
  final String? thisTimePhrase;
}

abstract final class PatternChangedEngine {
  PatternChangedEngine._();

  static const _maxPhraseWords = 6;

  static PatternChangedResult? build({
    required RepeatReturnCheckChangeProof? changeProof,
    required List<RepeatReturnCheckRecord> records,
    required List<JournalEntry> entries,
  }) {
    if (changeProof == null) return null;
    if (!RepeatReturnCheckTrendEngine.hasAnsweredCheck(records)) return null;

    final entryId = _latestAnsweredEntryId(records);
    if (entryId == null || entryId.isEmpty) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    final foundation = eligible.length >= 3 ? eligible.sublist(0, 3) : eligible;
    final latestEntry = eligible.last;
    final earlierPhrase = _groundedPhrase(foundation);
    final thisTimePhrase =
        ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
          latestEntry,
        );

    if (!_isMeaningfulChange(
      latestChoice: changeProof.latestChoice,
      earlierPhrase: earlierPhrase,
      thisTimePhrase: thisTimePhrase,
    )) {
      return null;
    }

    final usesPhraseEvidence = _canUsePhraseBody(earlierPhrase, thisTimePhrase);
    final body = usesPhraseEvidence
        ? PatternChangedCopy.bodyWithPhrases(earlierPhrase!, thisTimePhrase!)
        : PatternChangedCopy.bodyFallback;

    return PatternChangedResult(
      type: PatternChangedType.changed,
      title: PatternChangedCopy.title,
      body: body,
      footer: PatternChangedCopy.footer,
      entryId: entryId,
      isCelebration: true,
      usesPhraseEvidence: usesPhraseEvidence,
      earlierPhrase: usesPhraseEvidence ? earlierPhrase : null,
      thisTimePhrase: usesPhraseEvidence ? thisTimePhrase : null,
    );
  }

  static bool _isMeaningfulChange({
    required RepeatReturnCheckChoice latestChoice,
    required String? earlierPhrase,
    required String? thisTimePhrase,
  }) {
    return switch (latestChoice) {
      RepeatReturnCheckChoice.changed => true,
      RepeatReturnCheckChoice.softer => _phrasesMeaningfullyDiffer(
        earlierPhrase,
        thisTimePhrase,
      ),
      RepeatReturnCheckChoice.stronger || RepeatReturnCheckChoice.same => false,
    };
  }

  static bool _phrasesMeaningfullyDiffer(String? earlier, String? thisTime) {
    if (earlier == null || thisTime == null) return false;
    return earlier.toLowerCase().trim() != thisTime.toLowerCase().trim();
  }

  static bool _canUsePhraseBody(String? earlier, String? thisTime) {
    if (!_phrasesMeaningfullyDiffer(earlier, thisTime)) return false;
    return _phraseWithinLimit(earlier!) && _phraseWithinLimit(thisTime!);
  }

  static bool _phraseWithinLimit(String phrase) {
    final words = phrase.trim().split(RegExp(r'\s+'));
    return words.isNotEmpty && words.length <= _maxPhraseWords;
  }

  static String? _groundedPhrase(List<JournalEntry> entries) {
    final shared = ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(
      entries,
    );
    if (shared != null && _isGroundedPhrase(shared, entries)) {
      return shared;
    }

    for (final phrase in ConfirmedRepeatEvidencePhraseEngine.extract(
      entries,
    ).phrases) {
      if (_isGroundedPhrase(phrase, entries)) return phrase;
    }
    return null;
  }

  static bool _isGroundedPhrase(String phrase, List<JournalEntry> entries) {
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
      label: phrase,
      entries: entries,
    )) {
      return false;
    }
    return _phraseWithinLimit(phrase);
  }

  static String? _latestAnsweredEntryId(List<RepeatReturnCheckRecord> records) {
    for (final record in records) {
      if (record.choice != null) return record.entryId;
    }
    return null;
  }
}