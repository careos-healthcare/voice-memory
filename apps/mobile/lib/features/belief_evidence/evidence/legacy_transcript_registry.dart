/// Entry id → the fact that an entry's transcript origin was not recorded.
///
/// `TranscriptEvidenceIndex` holds text that may be quoted. This holds the
/// opposite: entries deliberately kept out of that index because
/// `TranscriptProvenance.unknownLegacy` means the stored text may be
/// speech-to-text or may be model output back-filled by the old capture path.
///
/// Without this, a legacy entry is indistinguishable at the UI from an entry
/// nobody ever loaded, and both render "Quote not loaded". They are different
/// facts: one is a transient load state, the other is permanent for that row
/// until the recording is re-read. Splitting them is the whole point of this
/// file.
///
/// Free of model and storage imports for the same reason
/// `TranscriptEvidenceIndex` is: the citation widgets depend on it and must
/// stay cheap to construct and to test.
library;

import 'dart:io';

/// What is known about one entry whose transcript origin is unverifiable.
class LegacyTranscriptRecord {
  const LegacyTranscriptRecord({
    required this.entryId,
    this.recordedAt,
    this.audioPath,
  });

  final String entryId;
  final DateTime? recordedAt;

  /// Path recorded for the entry's audio, if one was ever stored.
  ///
  /// A non-null value means the entry *claims* an audio file. Whether that
  /// file is still on disk is a separate question — ask
  /// [LegacyTranscriptRegistry.hasRecoverableAudio], which probes the
  /// filesystem, rather than reading this and assuming.
  final String? audioPath;

  bool get claimsAudio => audioPath?.trim().isNotEmpty ?? false;
}

/// Registry of entries whose transcript cannot be attributed to the user.
abstract final class LegacyTranscriptRegistry {
  LegacyTranscriptRegistry._();

  static final Map<String, LegacyTranscriptRecord> _records = {};

  /// Probe used to decide whether a claimed audio file is still on disk.
  ///
  /// Swappable so widget tests can describe a device without touching the real
  /// filesystem. Mirrors `CitationPlaybackLauncher`, which decides the same
  /// question the same way before it will play a citation back.
  static bool Function(String path) audioProbe = _fileExists;

  static bool _fileExists(String path) => File(path).existsSync();

  static void remember(LegacyTranscriptRecord record) {
    if (record.entryId.isEmpty) return;
    _records[record.entryId] = record;
  }

  static LegacyTranscriptRecord? recordFor(String entryId) =>
      _records[entryId];

  static bool isLegacy(String entryId) => _records.containsKey(entryId);

  /// Whether re-reading the recording could restore this entry's provenance.
  ///
  /// False when the entry never had audio and false when the file has since
  /// gone, so a recovery affordance is offered on entries where it can
  /// actually do something.
  static bool hasRecoverableAudio(String entryId) {
    final path = _records[entryId]?.audioPath?.trim();
    if (path == null || path.isEmpty) return false;
    try {
      return audioProbe(path);
    } on Object {
      // ignore: silent_catch_audit — an unreadable path must read as "no audio
      // to offer", never as an invitation to upload something that is not
      // there.
      return false;
    }
  }

  static int get recordCount => _records.length;

  static void resetForTest() {
    _records.clear();
    audioProbe = _fileExists;
  }
}
