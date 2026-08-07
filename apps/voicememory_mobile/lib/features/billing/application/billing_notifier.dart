import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../billing/billing_async_guard.dart';
import '../../../billing/billing_service.dart';
import '../../../billing/store_billing_port.dart';
import '../../../core/di/network_providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../../models/entitlement.dart';
import '../../../storage/entitlement_cache.dart';
import 'billing_state.dart';

/// Immutable billing boundary — mirrors [AuthSessionNotifier] Riverpod patterns.
class BillingNotifier extends Notifier<BillingState> {
  @override
  BillingState build() {
    ref.onDispose(() => _rcSub?.cancel());
    return const BillingState();
  }

  BillingRepository get _repository => ref.read(billingRepositoryProvider);
  EntitlementCache get _cache => ref.read(entitlementCacheProvider);
  StoreBillingPort get _revenueCat => ref.read(storeBillingPortProvider);

  StreamSubscription<PremiumEntitlements>? _rcSub;

  void startListening() {
    _rcSub?.cancel();
    _rcSub = _revenueCat.entitlementStream.listen((ent) {
      final merged = BillingService.mergeEntitlements(
        server: state.entitlements,
        store: ent,
        revenueCatConfigured: _revenueCat.isConfigured,
      );
      state = state.copyWith(entitlements: merged, phase: BillingPhase.ready);
    });
  }

  Future<PremiumEntitlements?> loadCachedEntitlements() async {
    if (state.entitlements != null) return state.entitlements;
    return _cache.load();
  }

  Future<PremiumEntitlements> loadEntitlements({
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && state.entitlements != null) {
        return state.entitlements!;
      }

      state = state.copyWith(
        phase: BillingPhase.loading,
        clearLastFailure: true,
      );

      final storeEnt = _revenueCat.isConfigured
          ? await _revenueCat.refreshEntitlements()
          : PremiumEntitlements.free();

      PremiumEntitlements serverEnt;
      final serverResult = await withBillingTimeout(
        _repository.fetchEntitlements(),
        label: 'loadEntitlements.fetchEntitlements',
      );

      if (serverResult == null) {
        debugPrint('Billing: server entitlements timed out — using cache');
        serverEnt = await _cache.load() ?? PremiumEntitlements.free();
      } else {
        serverEnt = await serverResult.when(
          success: (entitlements) async {
            try {
              await _cache.save(entitlements);
            } catch (e) {
              debugPrint('Billing: cache save skipped — $e');
            }
            return entitlements;
          },
          onFailure: (failure) async {
            _logFailure('loadEntitlements', failure);
            state = state.copyWith(lastFailure: failure);
            return await _cache.load() ?? PremiumEntitlements.free();
          },
        );
      }

      final merged = BillingService.mergeEntitlements(
        server: serverEnt,
        store: storeEnt,
        revenueCatConfigured: _revenueCat.isConfigured,
      );
      state = state.copyWith(entitlements: merged, phase: BillingPhase.ready);
      await _persistEntitlements(merged);
      return merged;
    } catch (e, st) {
      debugPrint('Billing: loadEntitlements failed — free tier: $e');
      if (kDebugMode) debugPrint('$st');
      final free = PremiumEntitlements.free();
      state = state.copyWith(entitlements: free, phase: BillingPhase.ready);
      return free;
    }
  }

  Future<PremiumEntitlements> purchaseNative(Package package) async {
    final ent = await _revenueCat.purchasePackage(package);
    state = state.copyWith(entitlements: ent, phase: BillingPhase.ready);
    await _persistEntitlements(ent);
    return ent;
  }

  Future<PremiumEntitlements> restoreNative() async {
    final restored = await _revenueCat.restorePurchases();
    state = state.copyWith(entitlements: restored, phase: BillingPhase.ready);
    await _persistEntitlements(restored);
    if (_revenueCat.isConfigured) {
      return loadEntitlements(forceRefresh: true);
    }
    return restored;
  }

  Future<void> resetCachedEntitlementsForAuthChange() async {
    state = const BillingState(phase: BillingPhase.idle);
    try {
      await _cache.clear();
    } catch (e) {
      debugPrint('Billing: entitlement cache clear skipped — $e');
    }
  }

  Future<void> _persistEntitlements(PremiumEntitlements ent) async {
    try {
      if (ent.isPro) {
        await _cache.save(ent);
      } else if (_revenueCat.isConfigured) {
        await _cache.clear();
      } else {
        await _cache.save(ent);
      }
    } catch (e) {
      debugPrint('Billing: cache persist skipped — $e');
    }
  }

  void _logFailure(String operation, ApiFailure failure) {
    debugPrint(
      'Billing: $operation failed — ${failure.code}: ${failure.message}',
    );
  }
}

final billingProvider = NotifierProvider<BillingNotifier, BillingState>(
  BillingNotifier.new,
);

final billingNotifierProvider = Provider<BillingNotifier>(
  (ref) => ref.read(billingProvider.notifier),
);

final billingPhaseProvider = Provider<BillingPhase>(
  (ref) => ref.watch(billingProvider).phase,
);

final currentEntitlementsProvider = Provider<PremiumEntitlements?>(
  (ref) => ref.watch(billingProvider).entitlements,
);
