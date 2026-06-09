import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../models/entitlement.dart';
import '../storage/entitlement_cache.dart';
import 'billing_async_guard.dart';
import 'revenuecat_service.dart';

class BillingService {
  BillingService(this._api, this._cache, this._revenueCat);

  final ApiClient _api;
  final EntitlementCache _cache;
  final RevenueCatService _revenueCat;

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
  ) {
    if (store.isPro) return store;
    return server ?? store;
  }

  Future<PremiumEntitlements> loadEntitlements({bool forceRefresh = false}) async {
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
      if (_memory!.isPro) {
        try {
          await _cache.save(_memory!);
        } catch (e) {
          debugPrint('Billing: cache save skipped — $e');
        }
      }
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
    await _cache.save(ent);
    return ent;
  }

  Future<PremiumEntitlements> restoreNative() async {
    final ent = await _revenueCat.restorePurchases();
    _memory = ent;
    await _cache.save(ent);
    return ent;
  }
}
