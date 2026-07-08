import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../billing/paywall_route_args.dart';
import '../../billing/paywall_source.dart';
import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/purchase_smoke_test/purchase_smoke_test_copy.dart';
import '../../features/purchase_smoke_test/purchase_smoke_test_engine.dart';
import '../../features/purchase_smoke_test/purchase_smoke_test_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

typedef PurchaseSmokeTestOpenPaywallCallback = void Function(BuildContext context);

/// Beta-only purchase verification card — read-only checks, manual paywall open.
class PurchaseSmokeTestCard extends StatefulWidget {
  const PurchaseSmokeTestCard({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.snapshotOverride,
    this.onOpenPaywall,
  });

  final String source;
  final bool compact;
  final PurchaseSmokeTestSnapshot? snapshotOverride;
  final PurchaseSmokeTestOpenPaywallCallback? onOpenPaywall;

  @override
  State<PurchaseSmokeTestCard> createState() => _PurchaseSmokeTestCardState();
}

class _PurchaseSmokeTestCardState extends State<PurchaseSmokeTestCard> {
  PurchaseSmokeTestSnapshot? _snapshot;
  var _trackedOpened = false;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.snapshotOverride != null) {
      _snapshot = widget.snapshotOverride;
      return;
    }
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final snapshot = await PurchaseSmokeTestEngine.build();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
    _trackOpenedOnce(snapshot);
  }

  void _trackOpenedOnce(PurchaseSmokeTestSnapshot snapshot) {
    if (_trackedOpened) return;
    _trackedOpened = true;
    PurchaseSmokeTestAnalytics.opened(
      source: widget.source,
      billingConfigured: snapshot.billingConfigured,
      offeringsLoaded: snapshot.offeringsLoaded,
      entitlementKnown: snapshot.entitlementKnown,
    );
  }

  void _openPaywall(PurchaseSmokeTestSnapshot snapshot) {
    PurchaseSmokeTestAnalytics.paywallOpened(
      source: widget.source,
      billingConfigured: snapshot.billingConfigured,
      offeringsLoaded: snapshot.offeringsLoaded,
      entitlementKnown: snapshot.entitlementKnown,
    );
    final callback = widget.onOpenPaywall;
    if (callback != null) {
      callback(context);
      return;
    }
    context.push(
      '/subscription',
      extra: const PaywallRouteArgs(
        source: PaywallSource.generalPro,
        sourceRoute: 'purchase_smoke_test',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PurchaseSmokeTestEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('purchase_smoke_test_hidden'),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink(
        key: Key('purchase_smoke_test_loading'),
      );
    }

    return Container(
      key: const Key('purchase_smoke_test_card'),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            snapshot.title,
            key: const Key('purchase_smoke_test_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.body,
            key: const Key('purchase_smoke_test_body'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (final check in snapshot.checks) ...[
            _CheckRow(check: check),
            const SizedBox(height: 6),
          ],
          if (snapshot.lastErrorSafe != null) ...[
            Text(
              snapshot.lastErrorSafe!,
              key: const Key('purchase_smoke_test_last_error'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              TextButton(
                key: const Key('purchase_smoke_test_refresh'),
                onPressed: _loading ? null : _refresh,
                child: Text(PurchaseSmokeTestCopy.refreshCta),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('purchase_smoke_test_open_paywall'),
                onPressed: () => _openPaywall(snapshot),
                child: Text(PurchaseSmokeTestCopy.openPaywallCta),
              ),
            ],
          ),
          Text(
            PurchaseSmokeTestCopy.localNote,
            key: const Key('purchase_smoke_test_note'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final PurchaseSmokeTestCheck check;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('purchase_smoke_test_check_${check.id.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  key: Key('purchase_smoke_test_label_${check.id.name}'),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  check.detailLabel,
                  key: Key('purchase_smoke_test_detail_${check.id.name}'),
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          Text(
            check.status.label,
            key: Key('purchase_smoke_test_status_${check.id.name}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _statusColor(check.status),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(PurchaseSmokeTestStatus status) {
    return switch (status) {
      PurchaseSmokeTestStatus.ready => AppColors.success,
      PurchaseSmokeTestStatus.warning => AppColors.warning,
      PurchaseSmokeTestStatus.blocked => AppColors.error,
      PurchaseSmokeTestStatus.unknown => AppTheme.muted,
    };
  }
}
