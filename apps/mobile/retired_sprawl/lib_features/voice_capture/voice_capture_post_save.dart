import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Post-save CTA policy when voice audio saved without usable transcript.
abstract class VoiceCapturePostSave {
  VoiceCapturePostSave._();

  static bool isDegradedVoiceEntry(JournalEntry entry) =>
      VoiceCaptureQuality.isDegradedVoiceCapture(entry);

  static bool showTypedFallbackPrimary(JournalEntry? entry) =>
      entry != null && isDegradedVoiceEntry(entry);

  static bool showViewPatternsPrimary(JournalEntry? entry) =>
      !showTypedFallbackPrimary(entry);
}