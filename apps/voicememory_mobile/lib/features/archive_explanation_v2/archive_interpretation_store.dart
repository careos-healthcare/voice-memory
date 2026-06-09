import '../../storage/mobile_prefs_store.dart';

/// Archive memory for interpretation journeys.
class ArchiveInterpretationStore {
  ArchiveInterpretationStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _stateKey = 'archiveInterpretationMemory';

  Future<DateTime?> readLastInterpretationViewed() async {
    final raw = await _prefs.readJsonMap(_stateKey);
    final s = raw?['lastInterpretationViewed']?.toString();
    return s != null ? DateTime.tryParse(s) : null;
  }

  Future<String?> readLastFollowupQuestionSeen() async {
    final raw = await _prefs.readJsonMap(_stateKey);
    return raw?['lastFollowupQuestionSeen']?.toString();
  }

  Future<void> markInterpretationViewed({
    required String insightId,
    required String kind,
  }) async {
    final prior = await _prefs.readJsonMap(_stateKey) ?? {};
    prior['lastInterpretationViewed'] = DateTime.now().toUtc().toIso8601String();
    prior['lastInterpretationInsightId'] = insightId;
    prior['lastInterpretationKind'] = kind;
    await _prefs.writeJsonMap(_stateKey, prior);
  }

  Future<void> markFollowupQuestionSeen(String question) async {
    final prior = await _prefs.readJsonMap(_stateKey) ?? {};
    prior['lastFollowupQuestionSeen'] = question;
    prior['lastFollowupQuestionSeenAt'] =
        DateTime.now().toUtc().toIso8601String();
    await _prefs.writeJsonMap(_stateKey, prior);
  }
}
