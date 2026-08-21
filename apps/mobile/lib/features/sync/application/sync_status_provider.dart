import 'package:archiveme_mobile/features/sync/application/background_sync_notifier.dart';
import 'package:archiveme_mobile/features/sync/application/network_connectivity_notifier.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive sync status for banners and header indicators.
final syncStatusProvider = Provider<SyncStatusSnapshot>((ref) {
  final sync = ref.watch(backgroundSyncProvider);
  final isOnline = ref.watch(networkConnectivityProvider);
  return SyncStatusSnapshot(sync: sync, isOnline: isOnline);
});
