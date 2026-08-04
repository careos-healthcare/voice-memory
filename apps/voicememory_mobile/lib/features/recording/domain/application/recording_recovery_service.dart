import '../../../../services/privacy/sensitive_temporary_audio_store.dart';

final class RecordingRecoverySnapshot {
  const RecordingRecoverySnapshot({required this.recoverableCount});

  final int recoverableCount;
  bool get hasRecoverableAudio => recoverableCount > 0;
}

final class RecordingRecoveryService {
  const RecordingRecoveryService({
    required this.temporaryAudio,
    this.ownerId = 'voice-capture',
  });

  final SensitiveTemporaryAudioStore temporaryAudio;
  final String ownerId;

  Future<RecordingRecoverySnapshot> inspect() async {
    await temporaryAudio.migrateLegacyOnce(knownOwnerId: ownerId);
    await temporaryAudio.purge();
    final items = await temporaryAudio.list(
      ownerId: ownerId,
      recoverableOnly: true,
    );
    return RecordingRecoverySnapshot(recoverableCount: items.length);
  }
}
