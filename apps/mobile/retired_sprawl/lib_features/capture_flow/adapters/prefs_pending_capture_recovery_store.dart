import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists pending voice capture metadata for interruption recovery.
class PrefsPendingCaptureRecoveryStore implements PendingCaptureRecoveryStore {
  PrefsPendingCaptureRecoveryStore(this._prefs);

  static const _key = 'capture_flow_pending_voice_v1';

  final MobilePrefsStore _prefs;

  @override
  Future<void> recordPendingVoice({
    required String audioPath,
    required int durationSeconds,
  }) async {
    await _prefs.writeString(_key, '$audioPath|$durationSeconds');
  }

  @override
  Future<PendingVoiceCapture?> readPendingVoice() async {
    final raw = await _prefs.readString(_key);
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final duration = int.tryParse(parts[1]);
    if (duration == null) return null;
    return PendingVoiceCapture(
      audioPath: parts[0],
      durationSeconds: duration,
    );
  }

  @override
  Future<void> clearPendingVoice() async {
    await _prefs.writeString(_key, '');
  }
}
