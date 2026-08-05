import '../../models/journal_entry.dart';
import '../../models/reflection.dart';
import '../../models/sync_status.dart';
import '../../services/capture_pipeline_service.dart';
import 'post_save_moment_detail_model.dart';

/// Attaches a short post-save detail to a saved moment — local only.
class PostSaveMomentDetailService {
  PostSaveMomentDetailService(this._pipeline);

  final CapturePipelineService _pipeline;

  Future<JournalEntry> saveDetail({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  }) => _pipeline.savePostSaveMomentDetail(
    parentEntry: parentEntry,
    detailType: detailType,
    detailText: detailText,
  );
}

JournalEntry buildLinkedDetailEntry({
  required JournalEntry existing,
  required String detailText,
}) => existing.copyWith(
  transcript: detailText.trim(),
  syncStatus: SyncStatus.localOnly,
);

JournalEntry buildNewLinkedDetailEntry({
  required String id,
  required String parentEntryId,
  required PostSaveMomentDetailType detailType,
  required String detailText,
  required int durationSeconds,
}) => JournalEntry(
  id: id,
  createdAt: DateTime.now().toUtc(),
  transcript: detailText.trim(),
  durationSeconds: durationSeconds,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
  captureContextTag: PostSaveMomentDetailType.linkedCaptureContextTag(
    type: detailType,
    parentEntryId: parentEntryId,
  ),
  keepSeparate: true,
);
