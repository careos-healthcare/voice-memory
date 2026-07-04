import '../features/activation/archive_insight_feedback.dart';
import '../features/insight_feedback/insight_feedback_store.dart';
import '../features/review_ritual/view_ritual_store.dart';
import '../features/activation/archive_workspace_hint_store.dart';
import '../features/helped_tracking/helped_tracking_store.dart';
import '../features/helped_tracking/helped_tracking_store.dart';
import '../features/entry_importance/entry_importance_store.dart';
import '../features/pattern_naming/pattern_name_store.dart';
import '../features/what_changed/what_changed_v2_store.dart';
import '../services/app_services.dart';
import 'private_data_service.dart';

/// Local privacy and data actions for Settings.
class LocalPrivacyDataControls {
  LocalPrivacyDataControls({
    PrivateDataService? privateDataService,
 }) : _privateDataService = privateDataService ??
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
    await WhatChangedV2Store.clearAll();
    await ArchiveInsightFeedbackStore.clearAll();
    await InsightFeedbackStore.clearAll();
    await ReviewRitualStore.clearAll();
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }

  Future<void> resetDismissedTips() async {
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }
}
