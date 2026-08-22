import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:archiveme_mobile/features/comparison_engine/comparison_engine.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Archive tab UI state for 0–2 eligible saved moments.
enum ArchiveTabFourState { empty, one, twoUnrelated, twoRelated }

/// Resolved Archive tab surface for early entry counts.
class ArchiveTabFourStateModel {
  const ArchiveTabFourStateModel({
    required this.state,
    required this.body,
    this.primaryCta,
    this.primaryAction = ArchiveHomeAction.none,
  });

  final ArchiveTabFourState state;
  final String body;
  final String? primaryCta;
  final ArchiveHomeAction primaryAction;

  bool get showPrimaryCta => primaryCta != null && primaryCta!.isNotEmpty;
}

/// Builds the strict four-state Archive tab model from saved entries.
abstract final class ArchiveTabFourStateEngine {
  ArchiveTabFourStateEngine._();

  static const _signalEngine = SecondSessionSignalEngine();
  static const _comparisonEngine = ComparisonEngine();

  /// Returns a model for 0–2 eligible moments; null when the ladder continues.
  static ArchiveTabFourStateModel? build({
    required List<JournalEntry> entries,
  }) {
    if (entries.isEmpty) {
      return const ArchiveTabFourStateModel(
        state: ArchiveTabFourState.empty,
        body: ArchiveTabFourStateCopy.emptyBody,
        primaryCta: ArchiveTabFourStateCopy.recordMomentCta,
        primaryAction: ArchiveHomeAction.record,
      );
    }

    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);
    if (eligibleCount == 0) return null;

    if (eligibleCount == 1) {
      return const ArchiveTabFourStateModel(
        state: ArchiveTabFourState.one,
        body: ArchiveTabFourStateCopy.oneBody,
      );
    }

    if (eligibleCount == 2) {
      if (!_signalEngine.hasGroundedRepeatMatch(entries)) {
        return const ArchiveTabFourStateModel(
          state: ArchiveTabFourState.twoUnrelated,
          body: ArchiveTabFourStateCopy.twoUnrelatedBody,
        );
      }

      final comparisonResult = _comparisonEngine.build(entries);
      final output = comparisonResult.output;
      if (output != null) {
        return ArchiveTabFourStateModel(
          state: ArchiveTabFourState.twoRelated,
          body: output.formatArchiveThreadBody(),
          primaryCta: ArchiveTabFourStateCopy.viewEvidenceCta,
          primaryAction: ArchiveHomeAction.viewEvidence,
        );
      }

      return const ArchiveTabFourStateModel(
        state: ArchiveTabFourState.twoUnrelated,
        body: ArchiveTabFourStateCopy.twoUnrelatedBody,
      );
    }

    return null;
  }
}