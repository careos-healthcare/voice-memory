import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hint_store.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_store.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_store.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/review_ritual/view_ritual_store.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Local privacy and data actions for Settings.
class LocalPrivacyDataControls {
  LocalPrivacyDataControls({PrivateDataService? privateDataService})
    : _privateDataService =
          privateDataService ??
          PrivateDataService(
            journalStore: AppServices.instance.journalStore,
            prefs: AppServices.instance.prefs,
          );

  final PrivateDataService _privateDataService;

  static LocalPrivacyDataControls instance() => LocalPrivacyDataControls();

  Future<void> clearLocalArchive() async {
    await _privateDataService.clearLocalArchiveData();
    await PatternNameStore.clearAll();
    await HelpedTrackingStore.clearAll();
    await EntryImportanceStore.clearAll();
    await ArchiveExclusionStore.clearAll();
    await WhatChangedV2Store.clearAll();
    await ArchiveInsightFeedbackStore.clearAll();
    await InsightFeedbackStore.clearAll();
    await ArchiveCorrectionStore.instance.clearAll();
    await ReviewRitualStore.clearAll();
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }

  Future<void> resetDismissedTips() async {
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }

  /// The observations this archive has been told to stop raising, so the
  /// customer can see what "Ignore forever" is currently suppressing.
  ///
  /// Only the structural record is returned. The rejected wording itself is
  /// deliberately not stored, so a surface built on this lists suppressions by
  /// their evidence rather than by replaying a sentence the user rejected.
  Future<List<ArchiveCorrection>> ignoredObservations({
    String? archiveScope,
  }) async {
    final store = ArchiveCorrectionStore.instance;
    await store.ensureLoaded();
    final scope = archiveScope ?? store.activeArchiveScope;

    return store.records
        .where(
          (item) =>
              !item.superseded &&
              item.choice == ArchiveCorrectionChoice.ignoreForever &&
              item.archiveScope == scope,
        )
        .toList(growable: false);
  }

  /// Reverses one "Ignore forever" so the observation may be raised again.
  ///
  /// Returns how many suppressions were lifted. The underlying records are
  /// superseded rather than deleted, so the history stays auditable and
  /// exportable.
  Future<int> stopIgnoring(ArchiveCorrection correction, {DateTime? now}) =>
      ArchiveCorrectionStore.instance.undoIgnoreForever(
        archiveScope: correction.archiveScope,
        semanticFramingFingerprint: correction.semanticFramingFingerprint,
        now: now,
      );
}