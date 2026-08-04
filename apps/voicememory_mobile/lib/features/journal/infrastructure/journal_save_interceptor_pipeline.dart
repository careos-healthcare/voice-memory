import '../../../models/journal_entry.dart';
import '../domain/interceptors/journal_save_interceptor.dart';

/// Runs narrowly registered journal save interceptors after persistence.
///
/// Commercial V1 does not start clinical telemetry, curiosity loops, or
/// notification scheduling as side effects of saving user-owned content.
class JournalSaveInterceptorPipeline {
  JournalSaveInterceptorPipeline(this._interceptors);

  @Deprecated('Clinical and notification interceptors are not in V1')
  factory JournalSaveInterceptorPipeline.clinicalDefaults({
    Object? hookRepository,
    Object? journalStore,
    Object? curiosityLoopRepository,
    Object? baselineStore,
    Object? trajectoryHistoryStore,
    Object? acousticSessionBridge,
    Object? metricsHistoryStore,
  }) => JournalSaveInterceptorPipeline.empty();

  factory JournalSaveInterceptorPipeline.empty() =>
      JournalSaveInterceptorPipeline(const []);

  final List<JournalSaveInterceptor> _interceptors;

  Future<void> execute(JournalEntry entry) async {
    if (_interceptors.isEmpty) return;
    await Future.wait(
      _interceptors.map((interceptor) => interceptor.onEntrySaved(entry)),
    );
  }
}
