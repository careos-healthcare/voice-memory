import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../billing/restore_purchases_copy.dart';
import '../billing/restore_purchases_flow.dart';
import '../billing/revenuecat_service.dart';
import '../billing/restore_production_evidence.dart';
import '../models/entitlement.dart';
import '../services/app_services.dart';
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
  PremiumEntitlements? _result;
  String? _evidenceJson;
  String? _inlineMessage;

  Future<void> _restore() async {
    final flow = _restoreFlow ??= RestorePurchasesFlow(
      billing: AppServices.instance.billing,
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
      if (result.outcome == RestorePurchasesOutcome.error) {
        final evidence = await RestoreProductionEvidence.toJson(success: false);
        setState(() {
          _evidenceJson = evidence;
          _inlineMessage = result.userMessage;
        });
        return;
      }
      final ent = result.entitlements ?? PremiumEntitlements.free();
      final evidence = await RestoreProductionEvidence.toJson(
        success: true,
        entitlements: ent,
      );
      if (mounted) {
        setState(() {
          _result = ent;
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
    final subscriptionsAvailable = RevenueCatService.instance.isConfigured;

    return PushedScreenShell(
      title: RestorePurchasesCopy.restoreScreenTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          if (!subscriptionsAvailable) ...[
            Text(
              RestorePurchasesCopy.billingUnavailable,
              style: const TextStyle(color: AppTheme.foreground, height: 1.45),
            ),
          ] else ...[
            const Text(
              RestorePurchasesCopy.restoreScreenBody,
              style: TextStyle(color: AppTheme.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _restore,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(RestorePurchasesCopy.restorePurchases),
            ),
          ],
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
          if (subscriptionsAvailable &&
              _evidenceJson != null &&
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
