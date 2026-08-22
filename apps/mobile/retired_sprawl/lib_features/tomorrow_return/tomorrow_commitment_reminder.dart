import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_model.dart';

/// Optional local reminder hook — safe no-op when push is not configured.
abstract class TomorrowCommitmentReminder {
  TomorrowCommitmentReminder._();

  static Future<void> scheduleIfAvailable(TomorrowCommitment commitment) async {
    try {
      if (commitment.promptText.isEmpty) return;
      // No local notification plugin in consumer build yet.
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Ignore — retention still works via in-app status card.
    }
  }
}