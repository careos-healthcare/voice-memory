import '../../../models/journal_entry.dart';
import '../domain/interceptors/journal_save_interceptor.dart';
import '../../curiosity_loop/infrastructure/interceptors/cognitive_baseline_interceptor.dart';
import '../../curiosity_loop/infrastructure/interceptors/cognitive_alert_interceptor.dart';
import '../../curiosity_loop/infrastructure/interceptors/cognitive_trajectory_interceptor.dart';
import '../../curiosity_loop/infrastructure/interceptors/curiosity_loop_trigger_interceptor.dart';
import '../../curiosity_loop/application/curiosity_hook_journal_store.dart';
import '../../curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import '../../curiosity_loop/repositories/cognitive_baseline_store.dart';
import '../../curiosity_loop/repositories/curiosity_hook_repository.dart';
import '../../curiosity_loop/repositories/curiosity_loop_repository.dart';

/// Runs registered journal save interceptors after persistence completes.
class JournalSaveInterceptorPipeline {
  JournalSaveInterceptorPipeline(this._interceptors);

  factory JournalSaveInterceptorPipeline.clinicalDefaults({
    CuriosityHookRepository? hookRepository,
    CuriosityHookJournalStore? journalStore,
    CuriosityLoopRepository? curiosityLoopRepository,
    CognitiveBaselineStore? baselineStore,
    ClinicalTrajectoryHistoryStore? trajectoryHistoryStore,
  }) {
    return JournalSaveInterceptorPipeline([
      CognitiveAlertInterceptor(),
      CognitiveBaselineInterceptor(baselineStore: baselineStore),
      CuriosityLoopTriggerInterceptor(repository: curiosityLoopRepository),
      CognitiveTrajectoryInterceptor(
        hookRepository: hookRepository,
        journalStore: journalStore,
        trajectoryHistoryStore: trajectoryHistoryStore,
      ),
    ]);
  }

  factory JournalSaveInterceptorPipeline.empty() {
    return JournalSaveInterceptorPipeline(const []);
  }

  final List<JournalSaveInterceptor> _interceptors;

  Future<void> execute(JournalEntry entry) async {
    if (_interceptors.isEmpty) return;
    await Future.wait(
      _interceptors.map((interceptor) => interceptor.onEntrySaved(entry)),
    );
  }
}
