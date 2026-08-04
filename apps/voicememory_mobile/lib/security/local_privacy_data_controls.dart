import '../features/activation/archive_insight_feedback.dart';
import '../features/insight_feedback/insight_feedback_store.dart';
import '../features/review_ritual/view_ritual_store.dart';
import '../features/activation/archive_workspace_hint_store.dart';
import '../features/helped_tracking/helped_tracking_store.dart';
import '../features/archive_controls/archive_exclusion_store.dart';
import '../features/entry_importance/entry_importance_store.dart';
import '../features/pattern_naming/pattern_name_store.dart';
import '../features/what_changed/what_changed_v2_store.dart';
import '../services/app_services.dart';
import '../services/ai/ai_accuracy_feedback_store.dart';
import '../services/product_analytics.dart';
import 'behavioral_log_export_service.dart';
import 'private_data_service.dart';

/// Local privacy and data actions for Settings.
class LocalPrivacyDataControls {
  LocalPrivacyDataControls({
    PrivateDataService? privateDataService,
    BehavioralLogExportService? behavioralLogs,
  }) : // Public named parameters cannot expose private field names.
       // ignore: prefer_initializing_formals
       _behavioralLogs = behavioralLogs,
       _privateDataService =
           privateDataService ??
           PrivateDataService(
             journalStore: AppServices.instance.journalStore,
             prefs: AppServices.instance.prefs,
             audioVault: AppServices.instance.journalAudioVault,
             modelWipe: AppServices.instance.wipeLocalLlamaModel,
             localDerivedDataWipe: AppServices.instance.wipeLocalDerivedAiData,
             auxiliaryAudioWipe: AppServices.instance.wipeQueuedAudioData,
           );

  final PrivateDataService _privateDataService;
  final BehavioralLogExportService? _behavioralLogs;

  BehavioralLogExportService get _resolvedBehavioralLogs =>
      _behavioralLogs ??
      (AppServices.isInitialized
          ? BehavioralLogExportService.instance()
          : throw StateError('Behavioral logs are not available.'));

  static LocalPrivacyDataControls instance() => LocalPrivacyDataControls();

  Future<void> clearLocalArchive() async {
    await _privateDataService.clearLocalArchiveData();
    if (_behavioralLogs != null || AppServices.isInitialized) {
      await _resolvedBehavioralLogs.clear();
    }
    await PatternNameStore.clearAll();
    await HelpedTrackingStore.clearAll();
    await EntryImportanceStore.clearAll();
    await ArchiveExclusionStore.clearAll();
    await WhatChangedV2Store.clearAll();
    await ArchiveInsightFeedbackStore.clearAll();
    await InsightFeedbackStore.clearAll();
    if (AppServices.isInitialized) {
      await AiAccuracyFeedbackStore(AppServices.instance.prefs).clear();
    }
    await ReviewRitualStore.clearAll();
    await ArchiveWorkspaceHintStore.resetDismissedTips();
    await ProductAnalytics.resetIdentityAndQueue();
  }

  Future<void> resetDismissedTips() async {
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }

  Future<BehavioralLogExportArtifact> exportBehavioralLogs() =>
      _resolvedBehavioralLogs.buildExport();

  Future<void> clearBehavioralLogs() => _resolvedBehavioralLogs.clear();
}
