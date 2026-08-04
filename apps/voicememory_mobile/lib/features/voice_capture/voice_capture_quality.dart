import 'dart:io';

import '../../models/journal_entry.dart';
import 'transcription/transcript_quality.dart';
import '../timeline/timeline_entry_display.dart';

/// Validates captured audio and whether a voice entry has usable spoken text.
abstract class VoiceCaptureQuality {
  VoiceCaptureQuality._();

  static const int minAudioBytes = 1000;

  static bool audioFileUsable(File file) {
    if (!file.existsSync()) return false;
    return file.lengthSync() >= minAudioBytes;
  }

  static bool isVoiceEntry(JournalEntry entry) {
    return entry.localAudioReference?.isNotEmpty == true;
  }

  static bool hasUsableSpokenText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) {
      return TranscriptQuality.isUsableEvidence(resolution.text);
    }
    return hasPersistedCaptureText(entry);
  }

  static bool isDegradedVoiceCapture(JournalEntry entry) =>
      isVoiceEntry(entry) && !hasUsableSpokenText(entry);

  static int displayTextLength(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.length;
    return 0;
  }

  static EntryDisplayTextSource displayTextSource(JournalEntry entry) =>
      resolveEntryDisplayText(entry).source;
}
