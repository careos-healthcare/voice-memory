import '../../storage/mobile_prefs_store.dart';
import 'archive_challenge_models.dart';

/// Persists at most one active archive challenge.
class ArchiveChallengeStore {
  ArchiveChallengeStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _activeKey = 'archiveChallengeActive';
  static const _dismissedIdKey = 'archiveChallengeDismissedId';

  Future<ArchiveChallenge?> readActive() async {
    final raw = await _prefs.readJsonMap(_activeKey);
    return ArchiveChallenge.fromJson(raw);
  }

  Future<void> writeActive(ArchiveChallenge? challenge) async {
    if (challenge == null) {
      await _prefs.writeJsonMap(_activeKey, {});
      return;
    }
    await _prefs.writeJsonMap(_activeKey, challenge.toJson());
  }

  Future<String?> readDismissedId() async => _prefs.readString(_dismissedIdKey);

  Future<void> dismiss(String challengeId) async {
    await _prefs.writeString(_dismissedIdKey, challengeId);
    await writeActive(null);
  }
}
