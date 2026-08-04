import 'archive_ownership_copy.dart';

/// One verified fact about how the archive is handled.
class ArchivePrivacyFact {
  const ArchivePrivacyFact({required this.title, required this.body});

  final String title;
  final String body;
}

/// A short, checkable privacy summary.
///
/// Every line describes behaviour that exists in this build. In particular the
/// encryption line stays inside what the code actually guarantees: local files
/// use authenticated AES-256-GCM, and sync encrypts on the client with a key
/// that never leaves the device — which is deliberately weaker than end-to-end,
/// because there is no key escrow and no recovery exchange, so a lost device
/// means a lost key.
abstract final class ArchivePrivacySummary {
  static const String title = 'Privacy summary';

  static const String intro = 'Seven facts, all of them checkable in the app.';

  static const ArchivePrivacyFact originals = ArchivePrivacyFact(
    title: 'Your originals stay yours',
    body:
        '${ArchiveOwnershipCopy.recordingsStayYours} Recordings, transcripts, '
        'and your own corrections belong to you. Opening, playing, editing, '
        'exporting, and deleting them never needs a subscription.',
  );

  static const ArchivePrivacyFact onDeviceTranscription = ArchivePrivacyFact(
    title: 'On-device transcription',
    body:
        '${ArchiveOwnershipCopy.transcriptionChoice} A local speech model can '
        'turn a recording into text without leaving this device once the model '
        'has been downloaded. Where the local model is unavailable, ArchiveMe '
        'asks before anything is uploaded.',
  );

  static const ArchivePrivacyFact onlineProcessing = ArchivePrivacyFact(
    title: 'When processing happens online',
    body:
        'Two jobs run on servers rather than on this device: transcription of '
        'the audio you send for online transcription, and interpretation of the '
        'saved text and eligible prior evidence that produces observations and '
        'comparisons. Each has its own choice and disclosure; agreeing to '
        'transcription never authorizes interpretation.',
  );

  static const ArchivePrivacyFact encryption = ArchivePrivacyFact(
    title: 'How storage is protected',
    body:
        'The archive file on this device is encrypted with authenticated '
        'AES-256-GCM, as are the recordings you keep, and the keys are held in '
        'platform secure storage. If you turn on sync, your data is encrypted '
        'before it is sent, using a key this device keeps. That key is never '
        'escrowed and never exchanged, so sync is not end-to-end encryption '
        'and nobody, including ArchiveMe, can restore your archive for you if '
        'this device is lost.',
  );

  static const ArchivePrivacyFact analytics = ArchivePrivacyFact(
    title: 'What usage analytics never receive',
    body:
        'Usage analytics receive catalogued product actions and coarse buckets '
        'only — never recordings, saved text, generated titles or topics, raw '
        'identifiers, email addresses, or account tokens.',
  );

  static const ArchivePrivacyFact export = ArchivePrivacyFact(
    title: 'Export',
    body:
        'Readable export carries your original timestamps, text, corrections, '
        'evidence, Changes history and weekly review history in readable and '
        'machine-readable files, but explicitly excludes audio bytes. Full '
        'export creates one ZIP with those files, available original '
        'recordings, checksums, and a versioned manifest. After sharing, the '
        'destination you choose controls the plaintext files.',
  );

  static const ArchivePrivacyFact deletion = ArchivePrivacyFact(
    title: 'Deletion',
    body:
        'Deleting one moment removes its text and its audio from this device. '
        'Deleting the whole archive clears saved moments, derived caches, '
        'temporary recordings, and destroys the audio vault key. This does not '
        'prove deletion from a processing provider or retract prior exports.',
  );

  static const List<ArchivePrivacyFact> facts = [
    originals,
    onDeviceTranscription,
    onlineProcessing,
    encryption,
    analytics,
    export,
    deletion,
  ];
}
