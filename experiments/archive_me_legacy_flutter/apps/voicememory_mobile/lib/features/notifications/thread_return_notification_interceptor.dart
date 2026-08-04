import '../../models/journal_entry.dart';
import '../journal/domain/interceptors/journal_save_interceptor.dart';
import 'thread_return_notification_service.dart';

/// Schedules the one-shot thread reminder after durable journal persistence.
class ThreadReturnNotificationInterceptor implements JournalSaveInterceptor {
  const ThreadReturnNotificationInterceptor();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    await ThreadReturnNotificationService.onMomentSaved(entry);
  }
}
