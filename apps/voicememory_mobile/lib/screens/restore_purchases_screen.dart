import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_error_message.dart';
import '../billing/revenuecat_service.dart';
import '../billing/restore_production_evidence.dart';
import '../billing/subscription_copy.dart';
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
  PremiumEntitlements? _result;
  String? _evidenceJson;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _result = null;
      _evidenceJson = null;
    });
    try {
      final ent = await AppServices.instance.billing.restoreNative();
      final evidence = await RestoreProductionEvidence.toJson(
        success: true,
        entitlements: ent,
      );
      if (mounted) {
        setState(() {
          _result = ent;
          _evidenceJson = evidence;
        });
      }
    } catch (e) {
      final evidence = await RestoreProductionEvidence.toJson(success: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(e, fallback: 'Restore failed. Try again.'),
            ),
          ),
        );
        setState(() => _evidenceJson = evidence);
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
      title: 'Restore Purchases',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          if (!subscriptionsAvailable) ...[
            const Text(
              SubscriptionCopy.temporarilyUnavailable,
              style: TextStyle(color: AppTheme.foreground, height: 1.45),
            ),
          ] else ...[
            const Text(
              'Restore a subscription you already bought on this Apple or Google account.',
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
                  : const Text('Restore'),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 24),
            Text(
              result.isPro
                  ? 'Your subscription is active again on this device.'
                  : 'Restore finished — no active subscription found.',
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
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.muted),
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
