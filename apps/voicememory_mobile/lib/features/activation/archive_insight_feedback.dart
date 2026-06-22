import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'archive_home_summary.dart';

/// Which archive insight surface the user is responding to.
enum ArchiveInsightTarget {
  archiveHome,
  weeklyReview,
  beliefEvidence,
  beliefUpdate,
}

/// Local feedback choice — never synced to a backend.
enum ArchiveInsightFeedbackChoice {
  feelsRight,
  notQuite,
}

/// User-facing copy for insight feedback controls.
abstract final class ArchiveInsightFeedbackCopy {
  static const feelsRight = VisibleArchiveProofCopy.insightFeedbackFeelsRight;

  static const notQuite = VisibleArchiveProofCopy.insightFeedbackNotQuite;

  static const hideThis = VisibleArchiveProofCopy.insightFeedbackHideThis;

  static const whySeeing = VisibleArchiveProofCopy.insightFeedbackWhySeeing;

  static const whySource = VisibleArchiveProofCopy.insightFeedbackWhySource;

  static const whyNotConclusion =
      VisibleArchiveProofCopy.insightFeedbackWhyNotConclusion;

  static const whyHide = VisibleArchiveProofCopy.insightFeedbackWhyHide;
}

/// Visibility gates — no controls on premature early-ladder surfaces.
abstract final class ArchiveInsightFeedbackGate {
  ArchiveInsightFeedbackGate._();

  static bool showForArchiveHome(ArchiveHomeStage stage) =>
      stage == ArchiveHomeStage.three ||
      stage == ArchiveHomeStage.four ||
      stage == ArchiveHomeStage.fivePlus;

  static bool showForWeeklyReview({required bool hasEnoughEvidence}) =>
      hasEnoughEvidence;

  static bool showForBeliefEvidence({required bool hasEnoughEvidence}) =>
      hasEnoughEvidence;

  static bool showForBeliefUpdate() => true;
}

/// Local-only store for insight feedback and hide state.
abstract final class ArchiveInsightFeedbackStore {
  ArchiveInsightFeedbackStore._();

  static const _prefsKey = 'archive_insight_feedback';

  static final Set<String> _hidden = <String>{};
  static final Map<String, int> _feelsRight = <String, int>{};
  static final Map<String, int> _notQuite = <String, int>{};

  static String archiveHomeId(ArchiveHomeStage stage) =>
      'archive_home_${stage.name}';

  static String targetId(ArchiveInsightTarget target) => target.name;

  static bool isHidden(String insightId) => _hidden.contains(insightId);

  static int feelsRightCount(String insightId) => _feelsRight[insightId] ?? 0;

  static int notQuiteCount(String insightId) => _notQuite[insightId] ?? 0;

  static void record(
    String insightId,
    ArchiveInsightFeedbackChoice choice,
  ) {
    switch (choice) {
      case ArchiveInsightFeedbackChoice.feelsRight:
        _feelsRight[insightId] = feelsRightCount(insightId) + 1;
      case ArchiveInsightFeedbackChoice.notQuite:
        _notQuite[insightId] = notQuiteCount(insightId) + 1;
    }
    _persist();
  }

  static void hide(String insightId) {
    _hidden.add(insightId);
    _persist();
  }

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw == null) return;
    _hidden
      ..clear()
      ..addAll(
        (raw['hidden'] as List<dynamic>? ?? []).whereType<String>(),
      );
    _feelsRight.clear();
    final feelsRightRaw = raw['feelsRight'];
    if (feelsRightRaw is Map) {
      for (final entry in feelsRightRaw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key != null && value is num) {
          _feelsRight[key] = value.toInt();
        }
      }
    }
    _notQuite.clear();
    final notQuiteRaw = raw['notQuite'];
    if (notQuiteRaw is Map) {
      for (final entry in notQuiteRaw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key != null && value is num) {
          _notQuite[key] = value.toInt();
        }
      }
    }
  }

  static void _persist() {
    if (!AppServices.isInitialized) return;
    // ignore: discarded_futures
    AppServices.instance.prefs.writeMap(_prefsKey, {
      'hidden': _hidden.toList()..sort(),
      'feelsRight': _feelsRight,
      'notQuite': _notQuite,
    });
  }

  @visibleForTesting
  static void resetForTest() {
    _hidden.clear();
    _feelsRight.clear();
    _notQuite.clear();
  }
}
