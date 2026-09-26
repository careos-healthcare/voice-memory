import 'dart:async';

import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Uploads a saved entry when cloud features are on. Local save still stands
/// if the request fails.
class JournalCloudLedgerInterceptor implements JournalSaveInterceptor {
  const JournalCloudLedgerInterceptor({this.service});

  final CloudSyncService? service;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    final cloud = service ?? CloudSyncService();
    unawaited(cloud.uploadEntryToLedger(entry));
  }
}
