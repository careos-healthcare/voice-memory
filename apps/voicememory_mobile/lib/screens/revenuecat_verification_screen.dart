import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_error_message.dart';
import '../config/developer_settings_gate.dart';
import '../billing/revenuecat_purchase_journey.dart';
import '../billing/revenuecat_service.dart';
import '../models/entitlement.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/debug_only_unavailable.dart';

/// Physical-device RevenueCat production verification — export evidence JSON.
class RevenueCatVerificationScreen extends StatefulWidget {
  const RevenueCatVerificationScreen({super.key});

  @override
  State<RevenueCatVerificationScreen> createState() =>
      _RevenueCatVerificationScreenState();
}

class _RevenueCatVerificationScreenState extends State<RevenueCatVerificationScreen> {
  final RevenueCatPurchaseJourney _journey = RevenueCatPurchaseJourney();
  final RevenueCatService _rc = RevenueCatService.instance;

  Offerings? _offerings;
  PremiumEntitlements? _entitlements;
  String? _appUserId;
  String? _message;
  String? _exportJson;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    _journey.sdkInitialized = _rc.isConfigured;
    final offerings = await _rc.fetchOfferings();
    final ent = await AppServices.instance.billing.loadEntitlements(forceRefresh: true);
    final userId = await _rc.getAppUserId();
    _journey.appUserId = userId;

    if (offerings?.current != null) {
      final ids = offerings!.current!.availablePackages
          .map((p) => p.storeProduct.identifier)
          .toList();
      _journey.markOfferingsLoaded(ids);
    }

    if (mounted) {
      setState(() {
        _offerings = offerings;
        _entitlements = ent;
        _appUserId = userId;
        _busy = false;
        final d = _rc.diagnostics;
        _message = _rc.isConfigured
            ? 'SDK ready — complete purchase then restore on this device'
            : 'SDK not configured — set REVENUECAT_* API keys at build time';
        if (d.lastRevenueCatError != null) {
          _message = '${_message!}\nlastRevenueCatError: ${d.lastRevenueCatError}';
        }
      });
    }
  }

  Package? _firstPackage() {
    final current = _offerings?.current;
    if (current == null || current.availablePackages.isEmpty) return null;
    return current.availablePackages.first;
  }

  Future<void> _purchase() async {
    final package = _firstPackage();
    if (package == null) {
      setState(() => _message = 'No packages in current offering');
      return;
    }
    setState(() => _busy = true);
    try {
      final ent = await AppServices.instance.billing.purchaseNative(package);
      _journey.markPurchaseSuccess(ent);
      setState(() {
        _entitlements = ent;
        _message = ent.isPro
            ? 'Purchase complete — entitlement active'
            : 'Purchase finished but Pro not active — check RevenueCat dashboard';
      });
    } catch (e) {
      setState(() => _message = userFacingErrorMessage(e, fallback: 'Purchase failed.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final ent = await AppServices.instance.billing.restoreNative();
      _journey.markRestoreSuccess(ent);
      setState(() {
        _entitlements = ent;
        _message = ent.isPro
            ? 'Restore complete — entitlement active'
            : 'Restore finished — no active subscription';
      });
    } catch (e) {
      setState(() => _message = userFacingErrorMessage(e, fallback: 'Restore failed.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    _journey.sdkInitialized = _rc.isConfigured;
    _journey.appUserId = await _rc.getAppUserId();
    final json = await _journey.exportEvidenceJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      setState(() {
        _busy = false;
        _exportJson = json;
        _message = _journey.productionPass
            ? 'PASSING journey — JSON copied. Commit revenuecat_store_tested.json'
            : 'JSON copied — set purchase_completed, entitlement_received, restore_completed via tests above';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'RevenueCat verify');
    }
    final ent = _entitlements ?? PremiumEntitlements.free();
    final d = _rc.diagnostics;
    final productIds = d.productIdentifiers.isNotEmpty
        ? d.productIdentifiers
        : (_offerings?.current?.availablePackages
                .map((p) => p.storeProduct.identifier)
                .toList() ??
            []);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('RevenueCat verify'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Physical device + sandbox account only. Complete purchase, confirm Pro, then restore. Export JSON and commit to the repo.',
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          _debugSection(
            'SDK initialized',
            _rc.isConfigured ? 'yes' : 'no',
          ),
          _debugSection('apiKeyMissing', '${d.apiKeyMissing}'),
          _debugSection(
            'Offerings loaded',
            d.offeringsLoaded ? 'yes' : 'no',
          ),
          _debugSection('offeringCount', '${d.offeringCount}'),
          _debugSection('packageCount', '${d.packageCount}'),
          _debugSection(
            'requestedOfferingId',
            d.requestedOfferingId ?? '—',
          ),
          _debugSection('currentOfferingId', d.currentOfferingId ?? '—'),
          _debugSection('Product IDs', productIds.isEmpty ? '—' : productIds.join(', ')),
          _debugSection('lastRevenueCatError', d.lastRevenueCatError ?? '—'),
          _debugSection(
            'Entitlement state',
            '${ent.tier.name} · ids: ${ent.entitlementIds.isEmpty ? "none" : ent.entitlementIds.join(", ")}',
          ),
          _debugSection(
            'Restore state (journey)',
            _journey.restoreCompleted ? 'completed' : 'not recorded',
          ),
          _debugSection('App user ID', _appUserId ?? '—'),
          const SizedBox(height: 8),
          _debugSection('purchase_completed', '${_journey.purchaseCompleted}'),
          _debugSection('entitlement_received', '${_journey.entitlementReceived}'),
          _debugSection('restore_completed', '${_journey.restoreCompleted}'),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: AppTheme.foreground)),
          ],
          const SizedBox(height: 20),
          _button('Refresh status', _refresh),
          _button('Load offerings', _refresh),
          _button('Test purchase (first package)', _purchase),
          _button('Test restore', _restore),
          _button('Export evidence JSON', _export),
          if (_exportJson != null) ...[
            const SizedBox(height: 16),
            const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(
              _exportJson!,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _debugSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.foreground)),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      ),
    );
  }
}
