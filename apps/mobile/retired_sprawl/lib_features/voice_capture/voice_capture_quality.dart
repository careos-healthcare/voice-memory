import 'dart:io';

import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Validates captured audio and whether a voice entry has usable spoken text.
abstract class VoiceCaptureQuality {
  VoiceCaptureQuality._();

  static const int minAudioBytes = 1000;

  static bool audioFileUsable(File file) {
    if (!file.existsSync()) return false;
    return file.lengthSync() >= minAudioBytes;
  }

  static bool isVoiceEntry(JournalEntry entry) {
    final path = entry.localAudioPath?.trim() ?? '';
    return path.isNotEmpty;
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