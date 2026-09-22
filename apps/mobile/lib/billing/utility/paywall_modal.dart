import 'dart:async';

import 'package:archiveme_mobile/billing/utility/entitlement_required_exception.dart';
import 'package:archiveme_mobile/billing/utility/freemium_quota.dart';
import 'package:archiveme_mobile/features/sync/presentation/widgets/provider_scope_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the store purchase sheet when a utility limit is reached.
abstract class PurchaseSheetPresenter {
  Future<void> present();
}

class NoopPurchaseSheetPresenter implements PurchaseSheetPresenter {
  @override
  Future<void> present() async {}
}

final purchaseSheetPresenterProvider = Provider<PurchaseSheetPresenter>(
  (ref) => NoopPurchaseSheetPresenter(),
);

/// Soft explanation that journaling and on-device search stay free.
class PaywallModal extends StatefulWidget {
  const PaywallModal({
    required this.limit,
    required this.presenter,
    super.key,
  });

  final UtilityLimit limit;
  final PurchaseSheetPresenter presenter;

  static Future<void> show(
    BuildContext context, {
    required EntitlementRequiredException exception,
    PurchaseSheetPresenter? presenter,
  }) {
    final PurchaseSheetPresenter resolved = presenter ??
        (hasRiverpodScope(context)
            ? ProviderScope.containerOf(
                context,
                listen: false,
              ).read(purchaseSheetPresenterProvider)
            : NoopPurchaseSheetPresenter());
    return showDialog<void>(
      context: context,
      builder: (context) => PaywallModal(
        limit: exception.limit,
        presenter: resolved,
      ),
    );
  }

  @override
  State<PaywallModal> createState() => _PaywallModalState();
}

class _PaywallModalState extends State<PaywallModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.presenter.present());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('utility_paywall_modal'),
      title: const Text('This part of ArchiveMe is Pro'),
      content: Text(_body(widget.limit)),
      actions: [
        TextButton(
          key: const Key('utility_paywall_not_now'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const Key('utility_paywall_see_pro'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('See Pro'),
        ),
      ],
    );
  }

  static String _body(UtilityLimit limit) {
    return switch (limit) {
      UtilityLimit.exportArchive =>
        'PDF and archive export keep a copy you can take with you. '
            'Journaling and on-device search stay free.',
      UtilityLimit.cloudLlm =>
        'Extra cloud answers are a Pro tool. '
            'Your on-device journal and search stay free.',
      UtilityLimit.mediaStorage =>
        'Media above 500 MB is part of Pro. '
            'Saving entries and searching them on this device stay free.',
    };
  }
}

/// Runs [check]. On a utility limit, shows [PaywallModal] and returns false.
Future<bool> guardUtilityAction(
  BuildContext context,
  void Function(UtilityEntitlementGate gate) check,
) async {
  final gate = hasRiverpodScope(context)
      ? ProviderScope.containerOf(
          context,
          listen: false,
        ).read(utilityEntitlementGateProvider)
      : UtilityEntitlementGate(FreemiumQuota.new);
  try {
    check(gate);
    return true;
  } on EntitlementRequiredException catch (error) {
    if (context.mounted) {
      await PaywallModal.show(context, exception: error);
    }
    return false;
  }
}
