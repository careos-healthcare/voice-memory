import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/subscription_models.dart';
import '../domain/subscription_repository.dart';
import 'subscription_data_sources.dart';

class DefaultSubscriptionRepository implements SubscriptionRepository {
  DefaultSubscriptionRepository(
    this._store,
    this._remote,
    this._cache, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SubscriptionStoreDataSource _store;
  final SubscriptionRemoteDataSource _remote;
  final SubscriptionCacheDataSource _cache;
  final DateTime Function() _now;
  final StreamController<SubscriptionState> _stateController =
      StreamController<SubscriptionState>.broadcast();

  SubscriptionState? _state;
  StreamSubscription<SubscriptionState>? _storeSubscription;
  Future<SubscriptionState>? _refreshInFlight;
  int _identityGeneration = 0;
  bool _disposed = false;

  @override
  SubscriptionState? get currentState => _state;

  @override
  SubscriptionAvailability get availability => _store.availability;

  @override
  Stream<SubscriptionState> watchState() async* {
    final current = _state;
    if (current != null) yield current;
    yield* _stateController.stream;
  }

  @override
  Future<SubscriptionState?> hydrateFromCache() async {
    final cached = await _cache.load();
    if (cached != null) _emit(cached);
    return cached;
  }

  @override
  Future<SubscriptionState?> loadCachedState() async {
    final current = _state;
    if (current == null) return _cache.load();
    if (!current.isPro) return current;

    final cached = await _cache.load();
    if (cached?.isPro == true) return current;

    final expired = SubscriptionState.free();
    _emit(expired);
    return expired;
  }

  @override
  Future<SubscriptionState> refresh({bool force = false}) {
    if (!force && _state != null) {
      return loadCachedState().then(
        (value) => value ?? SubscriptionState.free(),
      );
    }
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<SubscriptionState> _performRefresh() async {
    SubscriptionState storeState;
    try {
      storeState = _store.availability == SubscriptionAvailability.available
          ? await _store.refresh()
          : SubscriptionState.free(origin: SubscriptionStateOrigin.unavailable);
    } on Object catch (error) {
      debugPrint('Subscriptions: store refresh unavailable: $error');
      storeState = SubscriptionState.free(
        origin: SubscriptionStateOrigin.unavailable,
      );
    }

    SubscriptionState serverState;
    try {
      final fetched = await _remote.fetchState();
      serverState = fetched.copyWith(
        origin: SubscriptionStateOrigin.backend,
        verifiedAt: _now(),
        verification: SubscriptionVerification.verified,
      );
    } on SubscriptionAuthRequiredException {
      serverState = const SubscriptionState(
        tier: SubscriptionTier.free,
        entitlementIds: [],
        billingConnected: false,
        origin: SubscriptionStateOrigin.auth,
        verification: SubscriptionVerification.verified,
      );
      await _clearCacheSafely();
    } on Object catch (error) {
      debugPrint(
        'Subscriptions: backend refresh unavailable, retaining cache: $error',
      );
      serverState =
          await _cache.load() ??
          SubscriptionState.free(origin: SubscriptionStateOrigin.unavailable);
    }

    final merged = mergeStates(
      server: serverState,
      store: storeState,
      storeAvailable: _store.availability == SubscriptionAvailability.available,
    );
    _emit(merged);
    await _persist(merged);
    return merged;
  }

  @visibleForTesting
  static SubscriptionState mergeStates({
    required SubscriptionState? server,
    required SubscriptionState store,
    required bool storeAvailable,
  }) {
    if (store.isPro) return store;
    if (storeAvailable && store.canDowngrade) return store;
    return server ?? store;
  }

  @override
  Future<List<SubscriptionOffer>> loadOffers() => _store.loadOffers();

  @override
  Future<SubscriptionState> purchase(String offerId) async {
    final identityGeneration = _identityGeneration;
    final purchased = await _store.purchase(offerId);
    if (identityGeneration != _identityGeneration) {
      throw const SubscriptionAccountChangedException();
    }
    final merged = mergeStates(
      server: _state,
      store: purchased,
      storeAvailable: _store.availability == SubscriptionAvailability.available,
    );
    _emit(merged);
    await _persist(merged);
    return merged;
  }

  @override
  Future<SubscriptionState> restore() async {
    final identityGeneration = _identityGeneration;
    SubscriptionState? storeResult;
    if (_store.availability == SubscriptionAvailability.available) {
      try {
        final restored = await _store.restore();
        final refreshed = await _store.refresh();
        if (identityGeneration != _identityGeneration) {
          throw const SubscriptionAccountChangedException();
        }
        storeResult = _selectRestoreState(restored, refreshed);
        if (storeResult.isPro && storeResult.isVerified) {
          _emit(storeResult);
          await _persist(storeResult);
        }
      } on SubscriptionAccountChangedException {
        rethrow;
      } on Object catch (error) {
        debugPrint('Subscriptions: store restore unavailable: $error');
        return _offlineRestoreFallback(error);
      }
    }

    try {
      // Native restore is verified through the existing entitlement read.
      final serverResult = (await _remote.fetchState()).copyWith(
        origin: SubscriptionStateOrigin.backend,
        verifiedAt: _now(),
        verification: SubscriptionVerification.verified,
      );
      if (identityGeneration != _identityGeneration) {
        throw const SubscriptionAccountChangedException();
      }
      final selected = storeResult?.isPro == true && !serverResult.isPro
          ? storeResult!
          : serverResult;
      _emit(selected);
      await _persist(selected);
      return selected;
    } on SubscriptionAccountChangedException {
      rethrow;
    } on Object catch (error) {
      debugPrint('Subscriptions: restore verification unavailable: $error');
      if (storeResult?.isVerified == true) {
        _emit(storeResult!);
        await _persist(storeResult);
        return storeResult;
      }
      return _offlineRestoreFallback(error);
    }
  }

  SubscriptionState _selectRestoreState(
    SubscriptionState restored,
    SubscriptionState refreshed,
  ) {
    if (refreshed.isVerified) return refreshed;
    if (restored.isVerified) return restored;
    if (refreshed.isPro) return refreshed;
    return restored;
  }

  Future<SubscriptionState> _offlineRestoreFallback(Object error) async {
    final cached = await _cache.load();
    if (cached?.isPro == true) {
      final retained = cached!.copyWith(
        billingConnected: false,
        origin: SubscriptionStateOrigin.offline,
        verification: SubscriptionVerification.cached,
      );
      _emit(retained);
      // Never save here: an offline restore must not extend cache age.
      return retained;
    }
    throw SubscriptionRestoreException(cause: error);
  }

  @override
  Future<SubscriptionCheckout> createCheckout() => _remote.createCheckout();

  @override
  Future<void> updateIdentity(String? identity) async {
    await resetForAuthChange();
    final storeIdentity = await _store.updateIdentity(identity);
    if (identity != null && storeIdentity != null) {
      await _remote.linkStoreIdentity(storeIdentity);
    }
  }

  @override
  Future<void> resetForAuthChange() async {
    _identityGeneration++;
    await _clearCacheSafely();
    _emit(SubscriptionState.free(origin: SubscriptionStateOrigin.auth));
  }

  @override
  Future<SubscriptionDiagnostics> loadDiagnostics() => _store.loadDiagnostics();

  @override
  void start() {
    if (_disposed || _storeSubscription != null) return;
    _storeSubscription = _store.stateChanges.listen((storeState) async {
      final merged = mergeStates(
        server: _state,
        store: storeState,
        storeAvailable:
            _store.availability == SubscriptionAvailability.available,
      );
      _emit(merged);
      await _persist(merged);
    });
  }

  @override
  Future<void> stop() async {
    await _storeSubscription?.cancel();
    _storeSubscription = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _stateController.close();
  }

  void _emit(SubscriptionState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  Future<void> _persist(SubscriptionState state) async {
    try {
      if (state.isPro) {
        await _cache.save(state);
      } else if (state.canDowngrade) {
        await _cache.clear();
      } else {
        await _cache.save(state);
      }
    } on Object catch (error) {
      debugPrint('Subscriptions: cache persist skipped: $error');
    }
  }

  Future<void> _clearCacheSafely() async {
    try {
      await _cache.clear();
    } on Object catch (error) {
      debugPrint('Subscriptions: cache clear skipped: $error');
    }
  }
}
