import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/billing/restore_production_evidence.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/debug_only_unavailable.dart';

/// Production restore proof: purchase → delete app → reinstall → restore.
class RestoreProductionVerificationScreen extends StatefulWidget {
  const RestoreProductionVerificationScreen({super.key});

  @override
  State<RestoreProductionVerificationScreen> createState() =>
      _RestoreProductionVerificationScreenState();
}

class _RestoreProductionVerificationScreenState
    extends State<RestoreProductionVerificationScreen> {
  bool _purchaseConfirmed = false;
  bool _reinstallConfirmed = false;
  bool _busy = false;
  PremiumEntitlements? _result;
  String? _message;
  String? _exportJson;

  Future<void> _restoreAfterReinstall() async {
    if (!_purchaseConfirmed || !_reinstallConfirmed) {
      setState(
        () => _message = 'Confirm purchase and reinstall before restore',
      );
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
      _exportJson = null;
    });
    try {
      final ent = await AppServices.instance.billing.restoreNative();
      final json = await RestoreProductionEvidence.toJson(
        success: true,
        entitlements: ent,
      );
      if (mounted) {
        setState(() {
          _result = ent;
          _exportJson = json;
          _message = ent.isPro
              ? 'PASSING — Pro restored after reinstall. Copy JSON and commit restore_purchases_tested.json'
              : 'Restore ran but Pro not active — check sandbox subscription';
        });
      }
    } catch (e) {
      final json = await RestoreProductionEvidence.toJson(success: false);
      if (mounted) {
        setState(() {
          _exportJson = json;
          _message = userFacingErrorMessage(e, fallback: 'Restore failed.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyExport() async {
    if (_exportJson == null) return;
    await Clipboard.setData(ClipboardData(text: _exportJson!));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Evidence JSON copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(
        title: 'Restore production verify',
      );
    }
    final result = _result;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Restore production verify'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Full journey on a physical device with a sandbox subscription:\n'
            '1. Purchase\n'
            '2. Delete the app\n'
            '3. Reinstall (TestFlight / Play internal)\n'
            '4. Restore purchases on fresh install',
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          _step(
            title: '1. Purchase',
            done: _purchaseConfirmed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: () => context.push('/subscription'),
                  child: const Text('Open subscription (purchase)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _purchaseConfirmed = true;
                    _message = 'Purchase step marked — delete the app next';
                  }),
                  child: const Text('I completed a sandbox purchase'),
                ),
              ],
            ),
          ),
          _step(
            title: '2. Delete app',
            done: _purchaseConfirmed,
            child: const Text(
              'Remove ArchiveMe from this device completely.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
          _step(
            title: '3. Reinstall',
            done: _reinstallConfirmed,
            child: OutlinedButton(
              onPressed: _purchaseConfirmed
                  ? () => setState(() {
                      _reinstallConfirmed = true;
                      _message =
                          'Reinstall confirmed — tap Restore after opening this screen on fresh install';
                    })
                  : null,
              child: const Text('I reinstalled the app (fresh install)'),
            ),
          ),
          _step(
            title: '4. Restore',
            done: result?.isPro == true,
            child: FilledButton(
              onPressed: _busy || !_reinstallConfirmed
                  ? null
                  : _restoreAfterReinstall,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore purchases (after reinstall)'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: const TextStyle(color: AppTheme.foreground)),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            Text(
              result.isPro
                  ? 'Entitlement: Pro (${result.source})'
                  : 'Entitlement: free — success stays false in export',
              style: const TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
          ],
          if (_exportJson != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Evidence',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _exportJson!,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
            TextButton(
              onPressed: _copyExport,
              child: const Text('Copy evidence JSON'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step({
    required String title,
    required bool done,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 18,
                color: done ? Colors.greenAccent : AppTheme.muted,
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 26), child: child),
        ],
      ),
    );
  }
}
