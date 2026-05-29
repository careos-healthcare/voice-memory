import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../audio/recording_service.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';
import '../storage/journal_store.dart';
import '../storage/secure_storage.dart';
import '../billing/billing_service.dart';
import 'auth_service.dart';
import 'capture_attest_service.dart';
import 'capture_pipeline_service.dart';
import 'journal_service.dart';
import 'sync_service.dart';

/// App-wide services — initialized once at startup.
class AppServices {
  AppServices._();

  static AppServices? _instance;
  static bool _initialized = false;

  late final ApiClient api;
  late final DeviceIdStore deviceIds;
  late final SecureStorageService secureStorage;
  late final CaptureTokenCache tokenCache;
  late final CaptureAttestService attest;
  late final JournalStore journalStore;
  late final CapturePipelineService pipeline;
  late final RecordingService recording;
  late final JournalService journal;
  late final AuthService auth;
  late final BillingService billing;
  late final SyncService sync;

  static AppServices get instance {
    final i = _instance;
    if (i == null || !_initialized) {
      throw StateError('Call AppServices.initialize() first');
    }
    return i;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    final s = AppServices._();
    s.api = ApiClient();
    s.secureStorage = SecureStorageService();
    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      api: s.api,
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    final dir = await getApplicationDocumentsDirectory();
    s.journalStore = await JournalStore.open('${dir.path}/journal_entries.json');
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
    );
    s.recording = RecordingService();
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage);
    s.billing = BillingService(s.api);
    s.sync = SyncService(s.api);
    _instance = s;
    _initialized = true;
  }

  static Future<void> resetForTest({
    required String journalPath,
    ApiClient? api,
  }) async {
    _initialized = false;
    final s = AppServices._();
    s.api = api ?? ApiClient();
    s.secureStorage = SecureStorageService();
    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      api: s.api,
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    final file = File(journalPath);
    if (await file.exists()) await file.delete();
    s.journalStore = await JournalStore.open(journalPath);
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
    );
    s.recording = RecordingService(testMode: true);
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage);
    s.billing = BillingService(s.api);
    s.sync = SyncService(s.api);
    _instance = s;
    _initialized = true;
  }
}
