import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../billing/restore_purchases_copy.dart';
import '../billing/restore_purchases_flow.dart';
import '../billing/restore_production_evidence.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../theme/app_theme.dart';
import '../config/developer_settings_gate.dart';
import '../widgets/pushed_screen_shell.dart';

/// Restore → verify entitlement → show restored products + evidence template.
class RestorePurchasesScreen extends StatefulWidget {
  const RestorePurchasesScreen({super.key});

  @override
  State<RestorePurchasesScreen> createState() => _RestorePurchasesScreenState();
}

class _RestorePurchasesScreenState extends State<RestorePurchasesScreen> {
  bool _busy = false;
  RestorePurchasesFlow? _restoreFlow;
  SubscriptionState? _result;
  String? _evidenceJson;
  String? _inlineMessage;

  Future<void> _restore() async {
    final flow = _restoreFlow ??= RestorePurchasesFlow(
      repository: AppServices.instance.subscriptionRepository,
    );
    if (flow.isBusy || _busy) return;

    setState(() {
      _busy = true;
      _result = null;
      _evidenceJson = null;
      _inlineMessage = null;
    });
    try {
      final result = await flow.restore();
      if (!mounted || result.outcome == RestorePurchasesOutcome.skippedBusy) {
        return;
      }
      if (result.outcome == RestorePurchasesOutcome.error ||
          result.outcome == RestorePurchasesOutcome.unavailable ||
          result.outcome == RestorePurchasesOutcome.cachedAccessRetained) {
        final evidence = await RestoreProductionEvidence.toJson(success: false);
        setState(() {
          _result = result.subscriptionState;
          _evidenceJson = evidence;
          _inlineMessage = result.userMessage;
        });
        return;
      }
      final state = result.subscriptionState ?? SubscriptionState.free();
      final evidence = await RestoreProductionEvidence.toJson(
        success: true,
        subscriptionState: state,
      );
      if (mounted) {
        setState(() {
          _result = state;
          _evidenceJson = evidence;
          _inlineMessage = result.outcome == RestorePurchasesOutcome.restored
              ? RestorePurchasesCopy.restoreScreenSuccess
              : RestorePurchasesCopy.noActivePurchase;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return PushedScreenShell(
      title: RestorePurchasesCopy.restoreScreenTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          const Text(
            RestorePurchasesCopy.restoreScreenBody,
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton(
            // Restoring an existing purchase is independent of whether the
            // current RevenueCat offering loaded. Package availability may
            // disable a new purchase, but must never hide this recovery path.
            onPressed: _busy ? null : _restore,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(RestorePurchasesCopy.restorePurchases),
          ),
          if (_inlineMessage != null) ...[
            const SizedBox(height: 24),
            Text(
              _inlineMessage!,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ] else if (result != null) ...[
            const SizedBox(height: 24),
            Text(
              result.isPro
                  ? RestorePurchasesCopy.restoreScreenSuccess
                  : RestorePurchasesCopy.noActivePurchase,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
          if (_evidenceJson != null &&
              DeveloperSettingsGate.canShowInternalVerificationDetails) ...[
            const SizedBox(height: 24),
            const Text(
              'Restore details (for QA)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _evidenceJson!,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _evidenceJson!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Evidence JSON copied')),
                );
              },
              child: const Text('Copy evidence JSON'),
            ),
          ],
        ],
      ),
    );
  }
}
