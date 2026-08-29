import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/provider_scope_probe.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/sync_status_header_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AppBar [actions] entry that shows live sync status when relevant.
class SyncStatusAppBarAction extends ConsumerWidget {
  const SyncStatusAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Non-essential AppBar chrome: if pumped without a ProviderScope (some
    // lightweight widget tests), render nothing rather than throwing. Inert in
    // production, which always provides a scope at the root.
    if (!hasRiverpodScope(context)) return const SizedBox.shrink();
    final status = ref.watch(syncStatusProvider);
    if (!status.showHeaderIndicator) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: SyncStatusHeaderIndicator(status: status),
      ),
    );
  }
}

/// Merges [SyncStatusAppBarAction] with optional trailing AppBar actions.
List<Widget> syncStatusAppBarActions({List<Widget>? actions}) {
  return [
    const SyncStatusAppBarAction(),
    ...?actions,
  ];
}
