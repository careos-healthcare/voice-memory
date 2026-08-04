import 'dart:io';

import '../../../../services/privacy/audio_vault_service.dart';
import '../../../voice_capture/voice_capture_quality.dart';
import 'recording_ui_state_mapper.dart';

final class ProtectedTemporaryAudioService {
  const ProtectedTemporaryAudioService({this.vault});

  final AudioVaultService? vault;

  Future<void> requireUsable(File file) async {
    if (!await file.exists() ||
        await file.length() < VoiceCaptureQuality.minAudioBytes) {
      await discard(file);
      throw const RecordingAudioTooShort();
    }
  }

  Future<void> discard(File file) async {
    if (!await file.exists()) return;
    final audioVault = vault;
    if (audioVault != null) {
      await audioVault.secureDeletePlaintext(file);
      return;
    }
    await file.delete();
  }
}
