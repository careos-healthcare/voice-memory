import '../../../../models/journal_entry.dart';
import '../../../../services/app_services.dart';
import '../../../journal/domain/interceptors/journal_save_interceptor.dart';
import '../../application/curiosity_hook_journal_store.dart';
import '../../domain/models/curiosity_hook.dart';
import '../../domain/services/cognitive_trajectory_evaluator.dart';
import '../../repositories/clinical_trajectory_history_store.dart';
import '../../repositories/curiosity_hook_repository.dart';
import '../../services/cognitive_trajectory_telemetry.dart';

typedef CognitiveTrajectoryAssessmentHandler = void Function(
  CognitiveTrajectoryRecord record,
);

/// Evaluates hook-response recovery vectors after journal persistence.
class CognitiveTrajectoryInterceptor implements JournalSaveInterceptor {
  CognitiveTrajectoryInterceptor({
    CuriosityHookRepository? hookRepository,
    CuriosityHookJournalStore? journalStore,
    ClinicalTrajectoryHistoryStore? trajectoryHistoryStore,
    CognitiveTrajectoryEvaluator? evaluator,
    CognitiveTrajectoryTelemetry? telemetry,
    CognitiveTrajectoryAssessmentHandler? onAssessment,
    DateTime Function()? clock,
  })  : _hookRepository = hookRepository,
        _journalStore = journalStore,
        _trajectoryHistoryStore = trajectoryHistoryStore,
        _evaluator = evaluator ?? const CognitiveTrajectoryEvaluator(),
        _telemetry = telemetry ?? const CognitiveTrajectoryTelemetry(),
        _onAssessment = onAssessment,
        _clock = clock ?? DateTime.now;

  final CuriosityHookRepository? _hookRepository;
  final CuriosityHookJournalStore? _journalStore;
  final ClinicalTrajectoryHistoryStore? _trajectoryHistoryStore;
  final CognitiveTrajectoryEvaluator _evaluator;
  final CognitiveTrajectoryTelemetry _telemetry;
  final CognitiveTrajectoryAssessmentHandler? _onAssessment;
  final DateTime Function() _clock;

  CuriosityHookRepository get _resolvedHookRepository =>
      _hookRepository ?? LocalCuriosityHookRepository.instance();

  CuriosityHookJournalStore get _resolvedJournalStore =>
      _journalStore ??
      JournalStoreCuriosityHookJournalStore(AppServices.instance.journalStore);

  ClinicalTrajectoryHistoryStore get _resolvedTrajectoryHistoryStore =>
      _trajectoryHistoryStore ??
      LocalClinicalTrajectoryHistoryStore.instance();

  String _resolvedSourceEntryId(CuriosityHook hook) {
    final sourceEntryId = hook.sourceEntryId?.trim();
    if (sourceEntryId != null && sourceEntryId.isNotEmpty) {
      return sourceEntryId;
    }
    return hook.entryId.trim();
  }

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    final parentHookId = entry.parentHookId?.trim();
    if (parentHookId == null || parentHookId.isEmpty) return;

    final hook = await _resolvedHookRepository.fetchById(parentHookId);
    if (hook == null) return;

    final sourceEntryId = _resolvedSourceEntryId(hook);
    if (sourceEntryId.isEmpty) return;

    final sourceEntry = await _resolvedJournalStore.getEntryById(sourceEntryId);
    final sourceMetrics = sourceEntry?.biomarkers;
    final responseMetrics = entry.biomarkers;
    if (sourceMetrics == null || responseMetrics == null) return;

    final assessment = _evaluator.evaluateRecovery(
      sourceMetrics: sourceMetrics,
      responseMetrics: responseMetrics,
    );

    final wasGrounded = entry.wasGrounded;

    _telemetry.trackTrajectoryAssessed(
      entryId: entry.id,
      hookId: hook.id,
      sourceEntryId: sourceEntryId,
      assessment: assessment,
      wasGrounded: wasGrounded,
    );
    await _resolvedTrajectoryHistoryStore.appendRecord(
      StoredTrajectoryRecord.fromAssessment(
        date: _clock().toUtc(),
        entryId: entry.id,
        hookId: hook.id,
        assessment: assessment,
        wasGrounded: wasGrounded,
      ),
    );
    _onAssessment?.call(
      CognitiveTrajectoryRecord(
        entryId: entry.id,
        hookId: hook.id,
        sourceEntryId: sourceEntryId,
        assessment: assessment,
        wasGrounded: wasGrounded,
      ),
    );
  }
}
