import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';

/// Canonical data-flow map shared by consent copy and copy-alignment tests.
abstract final class RemoteProcessingDataFlow {
  RemoteProcessingDataFlow._();

  static const Map<RemoteProcessingPurpose, RemoteProcessingPurposeFlow>
  purposeFlows = {
    RemoteProcessingPurpose.remoteTranscription: RemoteProcessingPurposeFlow(
      purpose: RemoteProcessingPurpose.remoteTranscription,
      sendsAudio: true,
      sendsText: false,
      summary:
          'Recorded audio is sent to ArchiveMe servers for transcription when '
          'this purpose is enabled.',
    ),
    RemoteProcessingPurpose.remoteReflection: RemoteProcessingPurposeFlow(
      purpose: RemoteProcessingPurpose.remoteReflection,
      sendsAudio: false,
      sendsText: true,
      summary:
          'Transcript text is sent to ArchiveMe servers for reflection and '
          'comparison when this purpose is enabled.',
    ),
  };
}

class RemoteProcessingPurposeFlow {
  const RemoteProcessingPurposeFlow({
    required this.purpose,
    required this.sendsAudio,
    required this.sendsText,
    required this.summary,
  });

  final RemoteProcessingPurpose purpose;
  final bool sendsAudio;
  final bool sendsText;
  final String summary;
}
