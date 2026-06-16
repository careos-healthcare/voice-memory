import '../../models/journal_entry.dart';
import 'voice_capture_quality.dart';

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
