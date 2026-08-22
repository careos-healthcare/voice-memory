import 'dart:io';

import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:audioplayers/audioplayers.dart';

/// Launches local audio playback at a theory citation timestamp.
class CitationPlaybackLauncher {
  const CitationPlaybackLauncher({this.playerFactory = AudioPlayer.new});

  final AudioPlayer Function() playerFactory;

  /// Plays the recording a theory citation was drawn from.
  ///
  /// The guard runs before the quote is even inspected: a citation renders as
  /// text a caregiver session may be entitled to see, but the recording behind
  /// it is the archive owner's voice, unedited and including whatever was said
  /// around the quoted line. A refusal is raised rather than returned so it
  /// cannot be mistaken for "this citation has no audio".
  Future<void> play({
    required TheoryEvidenceQuote quote,
    required List<JournalEntry> entries,
  }) async {
    await CaregiverSessionGuard.assertOwnerAccess(
      CaregiverSessionGuard.playbackTheoryCitation,
    );

    if (!quote.hasCitationPlayback) return;

    JournalEntry? entry;
    for (final candidate in entries) {
      if (candidate.id == quote.entryId) {
        entry = candidate;
        break;
      }
    }
    final audioPath = entry?.localAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) return;
    if (!File(audioPath).existsSync()) return;

    final player = playerFactory();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(DeviceFileSource(audioPath));
      await player.seek(Duration(milliseconds: quote.startTimestampMs!));
    } finally {
      await player.dispose();
    }
  }
}
