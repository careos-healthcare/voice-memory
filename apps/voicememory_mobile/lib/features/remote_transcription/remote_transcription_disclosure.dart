import '../../storage/mobile_prefs_store.dart';

/// The two remote operations have different payloads and therefore require
/// separate acceptance records. Agreeing to send audio never authorizes
/// sending transcript text for interpretation.
enum RemoteProcessingPurpose { transcription, interpretation }

/// Increment whenever the meaning of the remote-transcription disclosure changes.
const remoteTranscriptionDisclosureVersion = '1';
const remoteTranscriptionDisclosureHeader =
    'x-vm-remote-transcription-disclosure-version';

final class RemoteTranscriptionDisclosureState {
  const RemoteTranscriptionDisclosureState({
    this.transcriptionAcceptedVersion,
    this.interpretationAcceptedVersion,
  });

  final String? transcriptionAcceptedVersion;
  final String? interpretationAcceptedVersion;

  bool isCurrentFor(RemoteProcessingPurpose purpose) =>
      acceptedVersionFor(purpose) == remoteTranscriptionDisclosureVersion;

  Map<String, dynamic> toJson() => {
    if (transcriptionAcceptedVersion != null)
      'transcriptionAcceptedVersion': transcriptionAcceptedVersion,
    if (interpretationAcceptedVersion != null)
      'interpretationAcceptedVersion': interpretationAcceptedVersion,
  };

  factory RemoteTranscriptionDisclosureState.fromJson(
    Map<String, dynamic>? json,
  ) {
    // The V1 legacy field covered transcription wording only. It must never be
    // upgraded into interpretation permission.
    final transcriptionVersion =
        json?['transcriptionAcceptedVersion'] ?? json?['acceptedVersion'];
    return RemoteTranscriptionDisclosureState(
      transcriptionAcceptedVersion: transcriptionVersion is String
          ? transcriptionVersion
          : null,
      interpretationAcceptedVersion:
          json?['interpretationAcceptedVersion'] is String
          ? json!['interpretationAcceptedVersion'] as String
          : null,
    );
  }

  String? acceptedVersionFor(RemoteProcessingPurpose purpose) =>
      switch (purpose) {
        RemoteProcessingPurpose.transcription => transcriptionAcceptedVersion,
        RemoteProcessingPurpose.interpretation => interpretationAcceptedVersion,
      };

  RemoteTranscriptionDisclosureState accepting(
    RemoteProcessingPurpose purpose,
  ) => RemoteTranscriptionDisclosureState(
    transcriptionAcceptedVersion:
        purpose == RemoteProcessingPurpose.transcription
        ? remoteTranscriptionDisclosureVersion
        : transcriptionAcceptedVersion,
    interpretationAcceptedVersion:
        purpose == RemoteProcessingPurpose.interpretation
        ? remoteTranscriptionDisclosureVersion
        : interpretationAcceptedVersion,
  );
}

enum RemoteTranscriptionDisclosureStatus { accepted, required }

final class RemoteTranscriptionDisclosureResult {
  const RemoteTranscriptionDisclosureResult._(this.status, this.version);

  const RemoteTranscriptionDisclosureResult.accepted(String version)
    : this._(RemoteTranscriptionDisclosureStatus.accepted, version);

  const RemoteTranscriptionDisclosureResult.required()
    : this._(RemoteTranscriptionDisclosureStatus.required, null);

  final RemoteTranscriptionDisclosureStatus status;
  final String? version;

  bool get isAccepted => status == RemoteTranscriptionDisclosureStatus.accepted;
}

abstract interface class RemoteTranscriptionDisclosureGate {
  Future<RemoteTranscriptionDisclosureResult> check({
    RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
  });
}

final class RemoteTranscriptionDisclosureStore
    implements RemoteTranscriptionDisclosureGate {
  RemoteTranscriptionDisclosureStore(
    this._prefs, {
    String Function()? archiveId,
  }) : _archiveId = archiveId ?? (() => 'guest');

  final MobilePrefsStore Function() _prefs;
  final String Function() _archiveId;

  static const storageKey = 'remoteTranscriptionDisclosureStateV1';

  String get _scope {
    final value = _archiveId().trim();
    return value.isEmpty ? 'unscoped' : value;
  }

  Future<RemoteTranscriptionDisclosureState> read() async {
    final all = await _prefs().readJsonMap(storageKey);
    final scopes = all?['scopes'];
    if (scopes is Map) {
      final scoped = scopes[_scope];
      return RemoteTranscriptionDisclosureState.fromJson(
        scoped is Map ? Map<String, dynamic>.from(scoped) : null,
      );
    }
    // Legacy acceptance was global. Recognize it only for the explicit guest
    // scope so it cannot authorize a signed-in archive.
    if (_scope == 'guest') {
      return RemoteTranscriptionDisclosureState.fromJson(all);
    }
    return const RemoteTranscriptionDisclosureState();
  }

  @override
  Future<RemoteTranscriptionDisclosureResult> check({
    RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
  }) async {
    final state = await read();
    return state.isCurrentFor(purpose)
        ? const RemoteTranscriptionDisclosureResult.accepted(
            remoteTranscriptionDisclosureVersion,
          )
        : const RemoteTranscriptionDisclosureResult.required();
  }

  Future<void> acceptCurrent({
    RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
  }) async {
    final next = (await read()).accepting(purpose);
    await _writeScoped(next);
  }

  Future<void> revoke({RemoteProcessingPurpose? purpose}) async {
    final current = await read();
    final next = RemoteTranscriptionDisclosureState(
      transcriptionAcceptedVersion:
          purpose == null || purpose == RemoteProcessingPurpose.transcription
          ? null
          : current.transcriptionAcceptedVersion,
      interpretationAcceptedVersion:
          purpose == null || purpose == RemoteProcessingPurpose.interpretation
          ? null
          : current.interpretationAcceptedVersion,
    );
    await _writeScoped(next);
  }

  Future<void> _writeScoped(RemoteTranscriptionDisclosureState state) async {
    await _prefs().updateMap(storageKey, (current) {
      final root = Map<String, dynamic>.from(current ?? const {});
      final existingScopes = root['scopes'];
      final scopes = existingScopes is Map
          ? Map<String, dynamic>.from(existingScopes)
          : <String, dynamic>{};
      final empty =
          state.transcriptionAcceptedVersion == null &&
          state.interpretationAcceptedVersion == null;
      if (empty) {
        scopes.remove(_scope);
      } else {
        scopes[_scope] = state.toJson();
      }
      return <String, dynamic>{'scopes': scopes};
    });
  }
}

final class DeniedRemoteTranscriptionDisclosureGate
    implements RemoteTranscriptionDisclosureGate {
  const DeniedRemoteTranscriptionDisclosureGate();

  @override
  Future<RemoteTranscriptionDisclosureResult> check({
    RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
  }) async => const RemoteTranscriptionDisclosureResult.required();
}
