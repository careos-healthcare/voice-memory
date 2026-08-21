import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/text_capture_handler.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';

class ImageCaptionHandler {
  ImageCaptionHandler({
    required CapturePipelineDependencies deps,
    required TextCaptureHandler textHandler,
  }) : _deps = deps,
       _textHandler = textHandler;

  final CapturePipelineDependencies _deps;
  final TextCaptureHandler _textHandler;

  Future<CapturePipelineOutcome> saveImageCaptionEntry({
    required String caption,
    required ImageEvidence imageEvidence,
    
  }) async {
    final outcome = await _textHandler.saveTextThought(
      transcript: caption,
      
    );

    return outcome.match(
      pipelineFailure,
      (result) async {
        final entry = result.entry;
        final withImage = entry.copyWith(
          imageEvidence: imageEvidence,
          captureSource: 'image_caption',
        );
        if (withImage.imageEvidence != entry.imageEvidence ||
            withImage.captureSource != entry.captureSource) {
          await _deps.journalStore.save(
            withImage,
            first25Source: 'image_caption_capture',
            captureKind: 'typed',
          );
        }
        await _indexImageEmbedding(
          entry: withImage,
          imageEvidence: imageEvidence,
        );
        return pipelineSuccess(
          CapturePipelineResult(
            entry: withImage,
            localSaved: result.localSaved,
            syncSucceeded: result.syncSucceeded,
            analysisSucceeded: result.analysisSucceeded,
            syncNote: result.syncNote,
            attachedTypedTextToVoiceEntry: result.attachedTypedTextToVoiceEntry,
            lowQualityTranscript: result.lowQualityTranscript,
          ),
        );
      },
    );
  }

  Future<void> _indexImageEmbedding({
    required JournalEntry entry,
    required ImageEvidence imageEvidence,
  }) async {
    final service = _deps.imageEmbeddingService;
    if (service == null) return;
    try {
      await service.indexJournalAttachment(
        entryId: entry.id,
        evidence: imageEvidence,
        journalEntryForMirror: entry,
      );
    } on Object catch (error) {
      // Embedding failure must not block journal capture.
      RecordPipelineLog.backgroundProcessingFailed(
        operation: 'image_embedding_index',
        error: error,
      );
    }
  }
}
