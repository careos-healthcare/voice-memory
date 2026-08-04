// Public named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import '../remote_transcription/remote_transcription_disclosure.dart';

/// The standing permission that lets anything leave this device.
///
/// Granting only ever happens inside the disclosure dialog, at the moment the
/// user is told what is about to be sent. Settings can read it and take it
/// away, but cannot hand it out.
abstract interface class OnlineProcessingPermission {
  Future<bool> isGranted();

  Future<void> withdraw();
}

/// Backed by the same acceptance record the upload paths consult.
final class DisclosureOnlineProcessingPermission
    implements OnlineProcessingPermission {
  const DisclosureOnlineProcessingPermission(this.store);

  final RemoteTranscriptionDisclosureStore store;

  @override
  Future<bool> isGranted() async {
    final transcription = await store.check(
      purpose: RemoteProcessingPurpose.transcription,
    );
    final interpretation = await store.check(
      purpose: RemoteProcessingPurpose.interpretation,
    );
    return transcription.isAccepted || interpretation.isAccepted;
  }

  @override
  Future<void> withdraw() => store.revoke();
}

/// Memory-backed permission, for tests and previews.
final class InMemoryOnlineProcessingPermission
    implements OnlineProcessingPermission {
  InMemoryOnlineProcessingPermission({bool granted = false})
    : _granted = granted;

  bool _granted;

  @override
  Future<bool> isGranted() async => _granted;

  @override
  Future<void> withdraw() async => _granted = false;
}
