import '../features/activation/archive_insight_feedback.dart';
import '../features/activation/archive_workspace_hint_store.dart';
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
    await ArchiveInsightFeedbackStore.clearAll();
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }

  Future<void> resetDismissedTips() async {
    await ArchiveWorkspaceHintStore.resetDismissedTips();
  }
}
