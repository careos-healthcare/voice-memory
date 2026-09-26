import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/insights/knowledge_forget_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Sends journal text to the server fact ledger when cloud features are on.
class CloudSyncService {
  CloudSyncService({
    Future<void> Function(String entryId, String transcript)? upload,
    Future<bool> Function()? isCloudSyncEnabled,
    Future<List<JournalEntry>> Function()? loadEntries,
    Future<Set<String>> Function()? forgottenLabels,
  }) : _upload = upload ?? _postToApi,
       _isCloudSyncEnabled = isCloudSyncEnabled ?? _readCloudPreference,
       _loadEntries = loadEntries ?? _readLocalEntries,
       _forgottenLabels = forgottenLabels ?? _readForgottenLabels;

  static const ingestPath = '/api/ledger/ingest';

  final Future<void> Function(String entryId, String transcript) _upload;
  final Future<bool> Function() _isCloudSyncEnabled;
  final Future<List<JournalEntry>> Function() _loadEntries;
  final Future<Set<String>> Function() _forgottenLabels;

  /// Posts one entry. Does nothing while cloud features are off.
  /// Forgotten labels are left out of the copy sent to the server.
  Future<void> uploadEntryToLedger(JournalEntry entry) async {
    if (!await _isCloudSyncEnabled()) return;
    if (entry.isDeleted) return;
    final transcript = omitForgottenLabels(
      entry.transcript.trim(),
      await _forgottenLabels(),
    );
    if (transcript.isEmpty) return;
    try {
      await _upload(entry.id, transcript);
    } on Object {
      return;
    }
  }

  /// Pushes every local journal entry once cloud features are on.
  static Future<void> backfillLocalEntries() {
    return CloudSyncService().backfill();
  }

  Future<void> backfill() async {
    if (!await _isCloudSyncEnabled()) return;
    final entries = await _loadEntries();
    for (final entry in entries) {
      await uploadEntryToLedger(entry);
    }
  }

  static Future<void> _postToApi(String entryId, String transcript) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.httpTransport.post(
      ingestPath,
      body: {'entryId': entryId, 'transcript': transcript},
    );
  }

  static Future<bool> _readCloudPreference() async {
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isCloudSyncEnabled;
  }

  static Future<List<JournalEntry>> _readLocalEntries() {
    if (!AppServices.isInitialized) return Future.value(const []);
    return AppServices.instance.journal.loadAll();
  }

  static Future<Set<String>> _readForgottenLabels() async {
    if (!AppServices.isInitialized) return {};
    return ForgottenKnowledge.load(AppServices.instance.prefs);
  }
}
