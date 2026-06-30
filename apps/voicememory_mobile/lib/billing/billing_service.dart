import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../models/entitlement.dart';
import '../storage/entitlement_cache.dart';
import 'billing_async_guard.dart';
import 'store_billing_port.dart';

class BillingService {
  BillingService(this._api, this._cache, this._revenueCat);

  final ApiClient _api;
  final EntitlementCache _cache;
  final StoreBillingPort _revenueCat;

  PremiumEntitlements? _memory;
  StreamSubscription<PremiumEntitlements>? _rcSub;

  void startListening() {
    _rcSub?.cancel();
    _rcSub = _revenueCat.entitlementStream.listen((ent) {
      _memory = _merge(_memory, ent);
    });
  }

  void dispose() {
    _rcSub?.cancel();
  }

  PremiumEntitlements _merge(
    PremiumEntitlements? server,
    PremiumEntitlements store,
  ) =>
      mergeEntitlements(
        server: server,
        store: store,
        revenueCatConfigured: _revenueCat.isConfigured,
      );

  /// When RevenueCat is configured and reports free, stale cached Pro must not win.
  static PremiumEntitlements mergeEntitlements({
    required PremiumEntitlements? server,
    required PremiumEntitlements store,
    required bool revenueCatConfigured,
  }) {
    if (store.isPro) return store;
    if (revenueCatConfigured && !store.isPro) return store;
    return server ?? store;
  }

  Future<PremiumEntitlements?> loadCachedEntitlements() async {
    if (_memory != null) return _memory;
    return _cache.load();
  }

  Future<PremiumEntitlements> loadEntitlements({
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && _memory != null) return _memory!;

      final PremiumEntitlements storeEnt = _revenueCat.isConfigured
          ? await _revenueCat.refreshEntitlements()
          : PremiumEntitlements.free();

      PremiumEntitlements? serverEnt;
      try {
        serverEnt = await withBillingTimeout(
          _api.getEntitlements(),
          label: 'loadEntitlements.getEntitlements',
        );
        if (serverEnt != null) {
          try {
            await _cache.save(serverEnt);
          } catch (e) {
            debugPrint('Billing: cache save skipped — $e');
          }
        } else {
          debugPrint('Billing: server entitlements timed out — using cache');
          serverEnt = await _cache.load() ?? PremiumEntitlements.free();
        }
      } on AuthRequiredException {
        serverEnt = PremiumEntitlements.free();
      } on ApiException {
        serverEnt = await _cache.load() ?? PremiumEntitlements.free();
      } catch (e) {
        debugPrint('Billing: loadEntitlements server error — $e');
        serverEnt = await _cache.load() ?? PremiumEntitlements.free();
      }

      _memory = _merge(serverEnt, storeEnt);
      await _persistEntitlements(_memory!);
      return _memory!;
    } catch (e, st) {
      debugPrint('Billing: loadEntitlements failed — free tier: $e');
      if (kDebugMode) debugPrint('$st');
      _memory = PremiumEntitlements.free();
      return _memory!;
    }
  }

  Future<PremiumEntitlements> purchaseNative(Package package) async {
    final ent = await _revenueCat.purchasePackage(package);
    _memory = ent;
    await _persistEntitlements(ent);
    return ent;
  }

  /// Restore via RevenueCat, refresh entitlements, and update local cache.
  Future<PremiumEntitlements> restoreNative() async {
    final restored = await _revenueCat.restorePurchases();
    _memory = restored;
    await _persistEntitlements(restored);
    if (_revenueCat.isConfigured) {
      _memory = await loadEntitlements(forceRefresh: true);
    }
    return _memory!;
  }

  /// Clears in-memory and on-disk entitlement cache after sign-out or account
  /// switch so the next session cannot inherit the prior user's Pro state.
  Future<void> resetCachedEntitlementsForAuthChange() async {
    _memory = null;
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
}
