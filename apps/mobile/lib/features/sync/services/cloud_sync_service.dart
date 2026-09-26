import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Sends journal text to the server fact ledger when cloud features are on.
class CloudSyncService {
  CloudSyncService({
    Future<void> Function(String entryId, String transcript)? upload,
    Future<bool> Function()? isCloudSyncEnabled,
    Future<List<JournalEntry>> Function()? loadEntries,
  }) : _upload = upload ?? _postToApi,
       _isCloudSyncEnabled = isCloudSyncEnabled ?? _readCloudPreference,
       _loadEntries = loadEntries ?? _readLocalEntries;

  static const ingestPath = '/api/ledger/ingest';

  final Future<void> Function(String entryId, String transcript) _upload;
  final Future<bool> Function() _isCloudSyncEnabled;
  final Future<List<JournalEntry>> Function() _loadEntries;

  /// Posts one entry. Does nothing while cloud features are off.
  Future<void> uploadEntryToLedger(JournalEntry entry) async {
    if (!await _isCloudSyncEnabled()) return;
    if (entry.isDeleted) return;
    final transcript = entry.transcript.trim();
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
}
