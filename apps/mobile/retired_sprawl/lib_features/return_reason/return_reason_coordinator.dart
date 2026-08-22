import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_engine.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_models.dart';
import 'package:archiveme_mobile/features/return_reason/return_reason_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';

/// Called when the user leaves the Beliefs tab — persists the return loop.
class ReturnReasonCoordinator {
  ReturnReasonCoordinator._();

  static const beliefsTabIndex = 2;

  @Deprecated('Use beliefsTabIndex')
  static const int discoverTabIndex = beliefsTabIndex;

  static Future<void> onLeftBeliefsTab() async {
    try {
      final entries = await AppServices.instance.journal.loadAll();
      if (entries.isEmpty) return;

      final state = buildArchiveStateObjectV3(entries: entries);
      final card = const ReturnReasonEngine().build(
        entries: entries,
        state: state,
      );

      final store = ReturnReasonStore(AppServices.instance.prefs);
      if (card == null) {
        await store.clear();
        return;
      }

      await store.write(card.state);
      await ProductAnalytics.trackStrings('return_reason_generated', {
        'kind': card.kind.name,
      });
    } catch (e, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('ReturnReasonCoordinator: $e');
        return true;
      }());
    }
  }

  static Future<void> onLeftDiscoverTab() => onLeftBeliefsTab();

  static Future<ReturnReasonCard?> loadCardForArchive() async {
    final store = ReturnReasonStore(AppServices.instance.prefs);
    final saved = await store.read();
    if (saved == null || !saved.hasContent) return null;

    final entries = await AppServices.instance.journal.loadAll();
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) {
      await store.clear();
      return null;
    }
    final state = buildArchiveStateObjectV3(entries: entries);
    final card = const ReturnReasonEngine().build(
      entries: entries,
      state: state,
    );

    if (card != null) {
      return ReturnReasonCard(
        kind: card.kind,
        leadLine: card.leadLine,
        bodyLines: card.bodyLines,
        state: saved,
        beliefQuote: card.beliefQuote,
        recordingsNeeded: card.recordingsNeeded,
      );
    }

    return _cardFromState(saved);
  }

  static Future<void> dismissStored() async {
    await ReturnReasonStore(AppServices.instance.prefs).clear();
  }

  static ReturnReasonCard? _cardFromState(ReturnReasonState saved) {
    final kind = ReturnReasonKind.values.asNameMap()[saved.kind];

    if (kind == ReturnReasonKind.conflictingEvidence) {
      return ReturnReasonCard(
        kind: ReturnReasonKind.conflictingEvidence,
        leadLine: 'Keep recording.',
        bodyLines: const [
          'Your reflections pull in different directions.',
          'ArchiveMe cannot yet determine whether:',
        ],
        beliefQuote: saved.beliefFocus,
        state: saved,
      );
    }

    if (kind == ReturnReasonKind.emergingBelief && saved.beliefFocus != null) {
      return ReturnReasonCard(
        kind: ReturnReasonKind.emergingBelief,
        leadLine: 'Keep recording.',
        bodyLines: [
          'A new pattern may be forming.',
          'How clear it feels:',
          'Continue recording.',
        ],
        beliefQuote: saved.beliefFocus,
        state: saved,
      );
    }

    if (saved.unresolvedPatterns.length >= 2) {
      final needed = saved.recordingsNeeded ?? 2;
      return ReturnReasonCard(
        kind: ReturnReasonKind.uncertainPatterns,
        leadLine: 'Keep recording.',
        bodyLines: [
          'ArchiveMe is still uncertain about:',
          ...saved.unresolvedPatterns.map((p) => '• $p'),
          '$needed more reflections may reveal a stronger pattern.',
        ],
        recordingsNeeded: needed,
        state: saved,
      );
    }

    if (kind == ReturnReasonKind.keepRecording &&
        saved.unresolvedPatterns.isNotEmpty) {
      final needed = saved.recordingsNeeded ?? 2;
      return ReturnReasonCard(
        kind: ReturnReasonKind.keepRecording,
        leadLine: 'Keep recording.',
        bodyLines: [
          'ArchiveMe is still forming its first clear patterns.',
          'ArchiveMe is still uncertain about:',
          ...saved.unresolvedPatterns.take(2).map((p) => '• $p'),
          '$needed more reflections may reveal a stronger pattern.',
        ],
        recordingsNeeded: needed,
        state: saved,
      );
    }

    if (saved.pendingQuestions.isNotEmpty) {
      return ReturnReasonCard(
        kind: ReturnReasonKind.uncertainPatterns,
        leadLine: 'Keep recording.',
        bodyLines: [
          'ArchiveMe has open questions it cannot answer yet.',
          ...saved.pendingQuestions.take(2).map((q) => '• $q'),
          'Continue recording.',
        ],
        state: saved,
      );
    }

    return null;
  }
}