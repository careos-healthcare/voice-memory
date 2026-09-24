import 'package:archiveme_mobile/features/archive/v1/feature_unlock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Archive-home slot for entry-count unlocks. Safe to construct as a const
/// widget; it only reads [featureUnlockProvider] when a Riverpod scope exists.
class FeatureUnlockDashboardSlot extends StatelessWidget {
  const FeatureUnlockDashboardSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final scoped =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    if (!scoped) return const SizedBox.shrink();
    return const _FeatureUnlockDashboardBody();
  }
}

class _FeatureUnlockDashboardBody extends ConsumerWidget {
  const _FeatureUnlockDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureUnlockProvider);
    if (!state.loaded) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }
}
