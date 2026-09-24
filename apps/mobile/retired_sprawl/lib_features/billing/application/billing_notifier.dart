import 'dart:async';

import 'package:archiveme_mobile/billing/billing_service.dart';
import 'package:archiveme_mobile/billing/store_billing_port.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/features/monetization/subscription_manager.dart';
import 'package:archiveme_mobile/features/auth/application/auth_session_notifier.dart' show AuthSessionNotifier;
import 'package:archiveme_mobile/features/billing/application/billing_startup_result.dart';
import 'package:archiveme_mobile/features/billing/application/billing_state.dart';
import 'package:archiveme_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:archiveme_mobile/storage/sqlite/pro_status_sqlite_repository.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Immutable billing boundary — mirrors [AuthSessionNotifier] Riverpod patterns.
class BillingNotifier extends Notifier<BillingState> {
  @override
  BillingState build() {
    ref.onDispose(() => _rcSub?.cancel());
    return const BillingState();
  }

  EntitlementCache get _cache => ref.read(entitlementCacheProvider);
  StoreBillingPort get _revenueCat => ref.read(storeBillingPortProvider);

  SubscriptionManager get _subscriptions => SubscriptionManager(
    store: _revenueCat,
    cache: _cache,
  );

  StreamSubscription<PremiumEntitlements>? _rcSub;

  void startListening() {
    unawaited(_rcSub?.cancel());
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

  /// Offline-first startup hydration: SQLite → JSON cache → RevenueCat.
  Future<BillingStartupResult> initializeOnStartup() async {
    if (state.entitlements != null && state.phase == BillingPhase.ready) {
      return BillingStartupResult(
        entitlements: state.entitlements!,
        source: BillingStartupSource.sqliteCache,
        revenueCatChecked: false,
        revenueCatReachable: false,
      );
    }

    state = state.copyWith(
      phase: BillingPhase.loading,
      clearLastFailure: true,
    );

    PremiumEntitlements? hydrated;
    var source = BillingStartupSource.offlineFallback;
    var revenueCatChecked = false;
    var revenueCatReachable = false;

    try {
      final sqliteRecord = await _tryLoadProStatusFromSqlite();
      if (sqliteRecord != null) {
        hydrated = sqliteRecord.entitlements;
        source = BillingStartupSource.sqliteCache;
      }

      hydrated ??= await _cache.load();
      if (hydrated != null && source == BillingStartupSource.offlineFallback) {
        source = BillingStartupSource.jsonCache;
        await _tryPersistProStatusToSqlite(
          hydrated,
          syncedFrom: 'json_cache',
        );
      }

      if (hydrated != null) {
        state = state.copyWith(
          entitlements: hydrated,
          phase: BillingPhase.ready,
        );
      }

      if (_revenueCat.isConfigured) {
        revenueCatChecked = true;
        try {
          final storeEnt = await _revenueCat.refreshEntitlements();
          revenueCatReachable = true;
          final merged = BillingService.mergeEntitlements(
            server: hydrated,
            store: storeEnt,
            revenueCatConfigured: true,
          );
          hydrated = merged;
          source = BillingStartupSource.revenueCat;
          state = state.copyWith(
            entitlements: merged,
            phase: BillingPhase.ready,
          );
          await _persistEntitlements(merged, syncedFrom: 'revenuecat');
        } on Object catch (error, stackTrace) {
          _logException('startup_revenuecat_unreachable', error, stackTrace);
        }
      }

      hydrated ??= PremiumEntitlements.free();
      if (state.entitlements == null) {
        state = state.copyWith(
          entitlements: hydrated,
          phase: BillingPhase.ready,
        );
      }

      if (hydrated.isPro) {
        await _syncLoopProFlag(isPro: true);
      }

      return BillingStartupResult(
        entitlements: hydrated,
        source: source,
        revenueCatChecked: revenueCatChecked,
        revenueCatReachable: revenueCatReachable,
      );
    } catch (error, stackTrace) {
      _logException('startup_failed', error, stackTrace);
      final free = hydrated ?? PremiumEntitlements.free();
      state = state.copyWith(entitlements: free, phase: BillingPhase.ready);
      return BillingStartupResult(
        entitlements: free,
        source: source,
        revenueCatChecked: revenueCatChecked,
        revenueCatReachable: revenueCatReachable,
      );
    }
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

      final entitlements = await _subscriptions.refresh(
        force: true,
        memory: state.entitlements,
      );
      state = state.copyWith(
        entitlements: entitlements,
        phase: BillingPhase.ready,
      );
      await _persistEntitlements(entitlements, syncedFrom: 'revenuecat');
      return entitlements;
    } catch (e, st) {
      _logException('load_entitlements_failed', e, st);
      final free = PremiumEntitlements.free();
      state = state.copyWith(entitlements: free, phase: BillingPhase.ready);
      return free;
    }
  }

  Future<PremiumEntitlements> purchaseNative(Package package) async {
    final ent = await _subscriptions.purchase(package);
    state = state.copyWith(entitlements: ent, phase: BillingPhase.ready);
    await _persistEntitlements(ent);
    return ent;
  }

  Future<PremiumEntitlements> restoreNative() async {
    final restored = await _subscriptions.restore();
    state = state.copyWith(entitlements: restored, phase: BillingPhase.ready);
    await _persistEntitlements(restored);
    if (_revenueCat.isConfigured) {
      return loadEntitlements(forceRefresh: true);
    }
    return restored;
  }

  Future<void> resetCachedEntitlementsForAuthChange() async {
    state = const BillingState();
    try {
      await _cache.clear();
    } catch (e) {
      _logException('entitlement_cache_clear_skipped', e);
    }
    try {
      await ref.read(proStatusSqliteRepositoryProvider).clear();
    } catch (e) {
      _logException('sqlite_pro_status_clear_skipped', e);
    }
  }

  Future<void> _persistEntitlements(
    PremiumEntitlements ent, {
    String syncedFrom = 'billing',
  }) async {
    try {
      if (ent.isPro) {
        await _cache.save(ent);
      } else if (_revenueCat.isConfigured) {
        await _cache.clear();
      } else {
        await _cache.save(ent);
      }
    } catch (e) {
      _logException('cache_persist_skipped', e);
    }

    await _tryPersistProStatusToSqlite(ent, syncedFrom: syncedFrom);

    if (ent.isPro) {
      await _syncLoopProFlag(isPro: true);
    }
  }

  Future<void> _tryPersistProStatusToSqlite(
    PremiumEntitlements ent, {
    required String syncedFrom,
  }) async {
    try {
      await ref
          .read(proStatusSqliteRepositoryProvider)
          .save(ent, syncedFrom: syncedFrom);
    } catch (e) {
      _logException('sqlite_pro_status_persist_skipped', e);
    }
  }

  Future<ProStatusRecord?> _tryLoadProStatusFromSqlite() async {
    try {
      return await ref.read(proStatusSqliteRepositoryProvider).load();
    } catch (e) {
      _logException('sqlite_pro_status_load_skipped', e);
      return null;
    }
  }

  Future<void> _syncLoopProFlag({required bool isPro}) async {
    if (!isPro || !AppServices.isInitialized) return;
    try {
      await ArchiveLoopEntitlementStore(AppServices.instance.prefs).setPro(true);
    } catch (e) {
      _logException('loop_pro_flag_sync_skipped', e);
    }
  }

  void _logException(String operation, Object error, [StackTrace? stackTrace]) {
    ReleaseLogger.exceptionFailure(
      event: 'billing_${operation}_failed',
      category: ReleaseLogCategory.billing,
      error: error,
    );
    if (kDebugMode && stackTrace != null) {
      debugPrint('$stackTrace');
    }
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