import 'dart:async';

import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_banner.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_header_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps primary shell content with reactive sync banner and header indicator.
class SyncStatusShell extends ConsumerStatefulWidget {
  const SyncStatusShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<SyncStatusShell> createState() => _SyncStatusShellState();
}

class _SyncStatusShellState extends ConsumerState<SyncStatusShell> {
  Timer? _retryTicker;

  @override
  void dispose() {
    _retryTicker?.cancel();
    super.dispose();
  }

  void _syncRetryTicker(SyncStatusSnapshot status) {
    final waitingForRetry =
        status.sync.phase == BackgroundSyncPhase.waitingForRetry;
    if (waitingForRetry && _retryTicker == null) {
      _retryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      return;
    }
    if (!waitingForRetry && _retryTicker != null) {
      _retryTicker!.cancel();
      _retryTicker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    _syncRetryTicker(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SyncStatusBanner(status: status),
        if (status.showHeaderIndicator)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: SyncStatusHeaderIndicator(status: status),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
