import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/subscription_billing_copy.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Self-serve billing settings — cancel, restore, and human support without dark patterns.
class BillingSettingsScreen extends ConsumerWidget {
  const BillingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionProvider);

    return PushedScreenShell(
      title: SubscriptionBillingCopy.title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            key: const Key('billing_settings_current_plan'),
            contentPadding: EdgeInsets.zero,
            title: const Text(SubscriptionBillingCopy.currentPlanTitle),
            subtitle: Text(
              subState.isPro
                  ? SubscriptionBillingCopy.proPlanActiveSubtitle
                  : SubscriptionBillingCopy.freePlanCappedSubtitle,
            ),
            trailing: subState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Chip(
                    label: Text(
                      subState.isPro
                          ? SubscriptionBillingCopy.proChipLabel
                          : SubscriptionBillingCopy.freeChipLabel,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: subState.isPro ? Colors.green : Colors.grey,
                  ),
          ),
          if (!subState.isPro && subState.purchasesEnabled) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('billing_settings_upgrade'),
              onPressed: () => context.push('/subscription'),
              child: const Text(SubscriptionBillingCopy.upgradeCta),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              SubscriptionBillingCopy.trustSectionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified_user),
            title: Text(SubscriptionBillingCopy.evidenceGuaranteeTitle),
            subtitle: Text(SubscriptionBillingCopy.evidenceGuaranteeBody),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              SubscriptionBillingCopy.managementSectionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            key: const Key('billing_settings_cancel_subscription'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cancel_outlined),
            title: const Text(SubscriptionBillingCopy.cancelSubscriptionTitle),
            subtitle: const Text(SubscriptionBillingCopy.cancelSubscriptionBody),
            onTap: () => _openStoreSubscriptions(ref),
          ),
          ListTile(
            key: const Key('billing_settings_restore'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore),
            title: const Text(SubscriptionBillingCopy.restoreTitle),
            subtitle: const Text(SubscriptionBillingCopy.restoreBody),
            onTap: subState.isLoading
                ? null
                : () => _restorePurchases(context, ref),
          ),
          ListTile(
            key: const Key('billing_settings_billing_support'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent),
            title: const Text(SubscriptionBillingCopy.billingSupportTitle),
            subtitle: const Text(SubscriptionBillingCopy.billingSupportBody),
            onTap: _openBillingSupport,
          ),
          if (subState.errorMessage case final error?) ...[
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _openStoreSubscriptions(WidgetRef ref) async {
    try {
      await ref.read(subscriptionNotifierProvider).openManageSubscriptions();
      return;
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Fall through to platform store URL.
    }

    final storeUrl = Uri.parse(
      defaultTargetPlatform == TargetPlatform.iOS
          ? SubscriptionBillingCopy.appleSubscriptionsUrl
          : SubscriptionBillingCopy.googleSubscriptionsUrl,
    );
    if (await canLaunchUrl(storeUrl)) {
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    await ref.read(subscriptionNotifierProvider).restorePurchases();
    if (!context.mounted) return;
    final isPro = ref.read(subscriptionProvider).isPro;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPro
              ? RestorePurchasesCopy.purchaseRestored
              : RestorePurchasesCopy.noActivePurchase,
        ),
      ),
    );
  }

  Future<void> _openBillingSupport() async {
    final supportUrl = Uri.parse(
      'mailto:${SubscriptionBillingCopy.billingSupportEmail}'
      '?subject=Billing%20Support',
    );
    if (await canLaunchUrl(supportUrl)) {
      await launchUrl(supportUrl);
    }
  }
}