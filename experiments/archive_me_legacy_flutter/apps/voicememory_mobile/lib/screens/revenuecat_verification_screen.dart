import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_error_message.dart';
import '../config/developer_settings_gate.dart';
import '../billing/revenuecat_purchase_journey.dart';
import '../billing/subscription_purchase_coordinator.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/debug_only_unavailable.dart';

/// Physical-device RevenueCat production verification — export evidence JSON.
class RevenueCatVerificationScreen extends StatefulWidget {
  const RevenueCatVerificationScreen({super.key});

  @override
  State<RevenueCatVerificationScreen> createState() =>
      _RevenueCatVerificationScreenState();
}

class _RevenueCatVerificationScreenState
    extends State<RevenueCatVerificationScreen> {
  final RevenueCatPurchaseJourney _journey = RevenueCatPurchaseJourney();

  List<SubscriptionOffer> _offers = const [];
  SubscriptionState? _entitlements;
  SubscriptionDiagnostics? _diagnostics;
  String? _message;
  String? _exportJson;
  bool _busy = false;
  SubscriptionPurchaseCoordinator? _purchaseCoordinator;

  SubscriptionRepository get _repository =>
      AppServices.instance.subscriptionRepository;

  SubscriptionPurchaseCoordinator get _coordinator => _purchaseCoordinator ??=
      SubscriptionPurchaseCoordinator(repository: _repository);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    _journey.sdkInitialized =
        _repository.availability == SubscriptionAvailability.available;
    final offers = await _repository.loadOffers();
    final ent = await _repository.refresh(force: true);
    final diagnostics = await _repository.loadDiagnostics();

    if (offers.isNotEmpty) {
      final ids = offers.map((offer) => offer.productIdentifier).toList();
      _journey.markOfferingsLoaded(ids);
    }

    if (mounted) {
      setState(() {
        _offers = offers;
        _entitlements = ent;
        _diagnostics = diagnostics;
        _busy = false;
        _message =
            _repository.availability == SubscriptionAvailability.available
            ? 'Store ready — complete purchase then restore on this device'
            : 'Subscription store is not configured for this build';
        if (diagnostics.lastError != null) {
          _message = '${_message!}\nlastError: ${diagnostics.lastError}';
        }
      });
    }
  }

  SubscriptionOffer? _firstOffer() => _offers.firstOrNull;

  Future<void> _purchase() async {
    final offer = _firstOffer();
    if (offer == null) {
      setState(() => _message = 'No subscription offers are available');
      return;
    }
    setState(() => _busy = true);
    try {
      final ent = await _coordinator.purchase(offer);
      _journey.markPurchaseSuccess(ent);
      setState(() {
        _entitlements = ent;
        _message = ent.isPro
            ? 'Purchase complete — entitlement active'
            : 'Purchase finished but Pro not active — check RevenueCat dashboard';
      });
    } catch (e) {
      setState(
        () =>
            _message = userFacingErrorMessage(e, fallback: 'Purchase failed.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final ent = await _coordinator.restore();
      _journey.markRestoreSuccess(ent);
      setState(() {
        _entitlements = ent;
        _message = ent.isPro
            ? 'Restore complete — entitlement active'
            : 'Restore finished — no active subscription';
      });
    } catch (e) {
      setState(
        () => _message = userFacingErrorMessage(e, fallback: 'Restore failed.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    _journey.sdkInitialized =
        _repository.availability == SubscriptionAvailability.available;
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
    final ent = _entitlements ?? SubscriptionState.free();
    final d = _diagnostics;
    final productIds = _offers.map((offer) => offer.productIdentifier).toList();

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
            'Store available',
            _repository.availability == SubscriptionAvailability.available
                ? 'yes'
                : 'no',
          ),
          _debugSection(
            'Offers loaded',
            d?.offersLoaded == true ? 'yes' : 'no',
          ),
          _debugSection('offerCount', '${d?.offerCount ?? 0}'),
          _debugSection(
            'Product IDs',
            productIds.isEmpty ? '—' : productIds.join(', '),
          ),
          _debugSection('lastError', d?.lastError ?? '—'),
          _debugSection(
            'Entitlement state',
            '${ent.tier.name} · ids: ${ent.entitlementIds.isEmpty ? "none" : ent.entitlementIds.join(", ")}',
          ),
          _debugSection(
            'Restore state (journey)',
            _journey.restoreCompleted ? 'completed' : 'not recorded',
          ),
          const SizedBox(height: 8),
          _debugSection('purchase_completed', '${_journey.purchaseCompleted}'),
          _debugSection(
            'entitlement_received',
            '${_journey.entitlementReceived}',
          ),
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
            const Text(
              'Preview',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppTheme.foreground),
            ),
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
