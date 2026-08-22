import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/return_check_payoff_engine.dart';
import 'package:archiveme_mobile/features/early_archive/return_check_payoff_model.dart';
import 'package:archiveme_mobile/features/early_archive/what_changed_since_last_time_copy.dart';
import 'package:archiveme_mobile/features/early_archive/what_changed_since_last_time_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the Patterns longitudinal change card from existing return-check engines.
abstract final class WhatChangedSinceLastTimeEngine {
  WhatChangedSinceLastTimeEngine._();

  static WhatChangedSinceLastTime? build({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) {
    final payoff = ReturnCheckPayoffEngine.build(
      entries: entries,
      returnChecks: returnChecks,
    );
    if (payoff == null) return null;

    if (payoff.state != ReturnCheckPayoffComparisonState.unknown &&
        !RepeatReturnCheckTrendEngine.hasAnsweredCheck(returnChecks)) {
      return null;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    final foundation = eligible.length >= 3 ? eligible.sublist(0, 3) : eligible;
    final latestEntry = eligible.last;

    final firstProofPhrase = _groundedPhrase(foundation);
    final latestPhrase =
        ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
          latestEntry,
        );
    final hasPhrase = firstProofPhrase != null || latestPhrase != null;

    final evidenceRows = [
      WhatChangedSinceLastTimeEvidenceRow(
        label: WhatChangedSinceLastTimeCopy.firstProofRowLabel,
        phrase: firstProofPhrase,
      ),
      WhatChangedSinceLastTimeEvidenceRow(
        label: WhatChangedSinceLastTimeCopy.latestReturnRowLabel,
        phrase: latestPhrase,
      ),
      WhatChangedSinceLastTimeEvidenceRow(
        label: WhatChangedSinceLastTimeCopy.changeRowLabel,
        phrase: WhatChangedSinceLastTimeCopy.changeValueFor(payoff.state),
      ),
    ];

    return WhatChangedSinceLastTime(
      state: payoff.state,
      title: WhatChangedSinceLastTimeCopy.title,
      summary: WhatChangedSinceLastTimeCopy.summaryFor(payoff.state),
      evidenceLabel: WhatChangedSinceLastTimeCopy.evidenceLabel,
      evidenceRows: evidenceRows,
      footer: WhatChangedSinceLastTimeCopy.footer,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: payoff.hasConfirmedRepeat,
    );
  }

  static String? _groundedPhrase(List<JournalEntry> entries) {
    final shared = ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(
      entries,
    );
    if (shared != null &&
        ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(shared) &&
        !ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(shared) &&
        !ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: shared,
          entries: entries,
        )) {
      return shared;
    }

    final extracted = ConfirmedRepeatEvidencePhraseEngine.extract(
      entries,
    ).phrases;
    for (final phrase in extracted) {
      if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
        continue;
      }
      if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
        continue;
      }
      if (ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
        label: phrase,
        entries: entries,
      )) {
        continue;
      }
      return phrase;
    }
    return null;
  }
}