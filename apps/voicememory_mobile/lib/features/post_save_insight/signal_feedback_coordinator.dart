import '../../services/app_services.dart';
import 'signal_feedback_model.dart';
import 'signal_feedback_store.dart';

/// Records post-save signal interactions locally.
abstract class SignalFeedbackCoordinator {
  SignalFeedbackCoordinator._();

  static SignalFeedbackStore _store() => SignalFeedbackStore.instance();

  static Future<void> track({
    required PostSaveSignalAction action,
    required String signalId,
    required String signalTitle,
    String? entryId,
    String? categoryId,
  }) async {
    if (!AppServices.isInitialized) return;
    await _store().save(
      PostSaveSignalFeedback(
        id: '${DateTime.now().millisecondsSinceEpoch}_$signalId',
        signalId: signalId,
        signalTitle: signalTitle,
        action: action,
        createdAt: DateTime.now(),
        entryId: entryId,
        categoryId: categoryId,
      ),
    );
  }
}
