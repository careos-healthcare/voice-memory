import 'package:archiveme_mobile/features/clinical_sandbox/runtime/clinical_sandbox_runtime.dart';
import 'package:archiveme_mobile/features/curiosity_loop/application/curiosity_hook_journal_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_alert_interceptor.dart';
import 'package:archiveme_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_baseline_interceptor.dart';
import 'package:archiveme_mobile/features/curiosity_loop/infrastructure/interceptors/cognitive_trajectory_interceptor.dart';
import 'package:archiveme_mobile/features/curiosity_loop/infrastructure/interceptors/curiosity_loop_trigger_interceptor.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/cognitive_baseline_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_loop_repository.dart';
import 'package:archiveme_mobile/features/journal/infrastructure/journal_save_interceptor_pipeline.dart';

/// Builds the clinical-signal interceptor pipeline when the sandbox is active.
abstract final class ClinicalSandboxPipeline {
  ClinicalSandboxPipeline._();

  /// Empty pipeline when feature flag or consent blocks clinical analysis.
  static JournalSaveInterceptorPipeline resolve({
    CuriosityHookRepository? hookRepository,
    CuriosityHookJournalStore? journalStore,
    CuriosityLoopRepository? curiosityLoopRepository,
    CognitiveBaselineStore? baselineStore,
    ClinicalTrajectoryHistoryStore? trajectoryHistoryStore,
  }) {
    if (!ClinicalSandboxRuntime.mayRunClinicalAnalysis) {
      return JournalSaveInterceptorPipeline([
        CuriosityLoopTriggerInterceptor(repository: curiosityLoopRepository),
      ]);
    }

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
}