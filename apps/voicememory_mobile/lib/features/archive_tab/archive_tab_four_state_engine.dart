import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../activation/archive_home_summary.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/archive_first_comparison_display.dart';
import '../retention/second_session_signal_engine.dart';
import 'archive_tab_four_state_copy.dart';

/// Archive tab UI state for 0–2 eligible saved moments.
enum ArchiveTabFourState {
  empty,
  one,
  twoUnrelated,
  twoRelated,
}

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

      final display = ArchiveFirstComparisonDisplay.resolve(entries);
      final comparison = _signalEngine.build(entries);
      final thread = _usableLine(display.evidenceLine) ??
          _usableLine(comparison.whatRepeated) ??
          'this thread';
      final change = _usableLine(display.whatChangedLine) ??
          _usableLine(comparison.whatChanged) ??
          'ArchiveMe is still comparing your saved words.';

      return ArchiveTabFourStateModel(
        state: ArchiveTabFourState.twoRelated,
        body: ArchiveTabFourStateCopy.twoRelatedBody(
          thread: thread,
          change: change,
        ),
        primaryCta: ArchiveTabFourStateCopy.viewEvidenceCta,
        primaryAction: ArchiveHomeAction.viewEvidence,
      );
    }

    return null;
  }

  static String? _usableLine(String? line) {
    final trimmed = line?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatRepeated) {
      return null;
    }
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatChanged) {
      return null;
    }
    return trimmed;
  }
}
