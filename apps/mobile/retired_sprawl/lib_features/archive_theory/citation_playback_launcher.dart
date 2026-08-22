import 'dart:io';

import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:audioplayers/audioplayers.dart';

/// Launches local audio playback at a theory citation timestamp.
class CitationPlaybackLauncher {
  const CitationPlaybackLauncher({this.playerFactory = AudioPlayer.new});

  final AudioPlayer Function() playerFactory;

  Future<void> play({
    required TheoryEvidenceQuote quote,
    required List<JournalEntry> entries,
  }) async {
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
