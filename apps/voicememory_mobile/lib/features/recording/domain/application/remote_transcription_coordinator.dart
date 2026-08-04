import 'dart:async';

import '../../../remote_transcription/remote_transcription_disclosure.dart';
import '../../../transcription_queue/transcription_queue_executor.dart';

enum RemoteTranscriptionChoice { continueOnline, typeInstead, cancel }

typedef RemoteTranscriptionDisclosureRequest =
    Future<RemoteTranscriptionChoice> Function();

final class RemoteTranscriptionCoordinator {
  RemoteTranscriptionCoordinator({
    required this.disclosure,
    required this.executor,
    required this.schedule,
  });

  final RemoteTranscriptionDisclosureGate disclosure;
  final TranscriptionQueueExecutor executor;
  final Future<void> Function() schedule;

  Stream<TranscriptionQueueCompletion> get completions => executor.completions;

  Future<RemoteTranscriptionChoice> authorize(
    RemoteTranscriptionDisclosureRequest requestDisclosure,
  ) async {
    if ((await disclosure.check()).isAccepted) {
      return RemoteTranscriptionChoice.continueOnline;
    }
    return requestDisclosure();
  }

  void start() {
    unawaited(executor.drain());
    unawaited(schedule());
  }
}
