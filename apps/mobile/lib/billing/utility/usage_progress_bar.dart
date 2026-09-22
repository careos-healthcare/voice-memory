import 'package:archiveme_mobile/billing/utility/freemium_quota.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/provider_scope_probe.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remaining free cloud answers and media storage.
class UsageProgressBar extends StatelessWidget {
  const UsageProgressBar({required this.quota, super.key, this.compact = false});

  final FreemiumQuota quota;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = quota.isPro
        ? 'Cloud answers included'
        : '${quota.cloudTokensRemaining} cloud answers left';
    final storage = quota.isPro
        ? 'Media storage included'
        : '${_megabytes(quota.mediaBytesRemaining)} MB of 500 MB left';
    return Semantics(
      container: true,
      label: '$tokens. $storage.',
      child: Padding(
        key: const Key('usage_progress_bar'),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 0, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tokens, key: const Key('usage_tokens_label')),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: quota.tokenFractionRemaining),
            const SizedBox(height: 8),
            Text(storage, key: const Key('usage_storage_label')),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: quota.storageFractionRemaining,
              color: AppColors.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class UsageProgressBarSlot extends StatelessWidget {
  const UsageProgressBarSlot({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!hasRiverpodScope(context)) {
      return UsageProgressBar(quota: const FreemiumQuota(), compact: compact);
    }
    return _LiveUsageProgressBar(compact: compact);
  }
}

class _LiveUsageProgressBar extends ConsumerWidget {
  const _LiveUsageProgressBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UsageProgressBar(
      quota: ref.watch(freemiumQuotaProvider),
      compact: compact,
    );
  }
}

int _megabytes(int bytes) => (bytes / (1024 * 1024)).round();
