import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monetization/domain/generated/monetization_policy.g.dart';
import 'package:voicememory_mobile/subscriptions/data/default_subscription_repository.dart';
import 'package:voicememory_mobile/subscriptions/data/legacy_subscription_mapper.dart';
import 'package:voicememory_mobile/subscriptions/data/subscription_data_sources.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';
import 'package:voicememory_mobile/models/entitlement.dart';

const _verifiedFree = SubscriptionState(
  tier: SubscriptionTier.free,
  entitlementIds: [],
  billingConnected: true,
  origin: SubscriptionStateOrigin.backend,
);

final _cachedPro = SubscriptionState(
  tier: SubscriptionTier.pro,
  entitlementIds: const ['archive_loop_pro'],
  billingConnected: true,
  origin: SubscriptionStateOrigin.cache,
  verifiedAt: DateTime.utc(2026, 7, 25),
  verification: SubscriptionVerification.cached,
);

class _MemoryCache implements SubscriptionCacheDataSource {
  _MemoryCache(this.value);

  SubscriptionState? value;
  int saves = 0;
  int clears = 0;

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }

  @override
  Future<SubscriptionState?> load() async => value;

  @override
  Future<void> save(SubscriptionState state) async {
    saves++;
    value = state;
  }
}

class _FakeRemote implements SubscriptionRemoteDataSource {
  _FakeRemote(this.fetch);

  final Future<SubscriptionState> Function() fetch;
  int fetches = 0;
  final List<String> linkedStoreIdentities = [];

  @override
  Future<SubscriptionState> fetchState() {
    fetches++;
    return fetch();
  }

  @override
  Future<SubscriptionCheckout> createCheckout() async =>
      const SubscriptionCheckout(url: 'https://example.test/checkout');

  @override
  Future<void> linkStoreIdentity(String storeIdentity) async {
    linkedStoreIdentities.add(storeIdentity);
  }
}

class _FakeStore implements SubscriptionStoreDataSource {
  _FakeStore({
    this.availability = SubscriptionAvailability.notConfigured,
    SubscriptionState? refreshed,
    SubscriptionState? restored,
    this.restoreError,
  }) : refreshed = refreshed ?? SubscriptionState.free(),
       restored = restored ?? SubscriptionState.free();

  @override
  final SubscriptionAvailability availability;
  SubscriptionState refreshed;
  SubscriptionState restored;
  Object? restoreError;
  int restores = 0;
  String? purchasedOfferId;
  final List<String?> identityUpdates = [];
  final StreamController<SubscriptionState> controller =
      StreamController<SubscriptionState>.broadcast();

  @override
  Stream<SubscriptionState> get stateChanges => controller.stream;

  @override
  Future<List<SubscriptionOffer>> loadOffers() async => const [
    SubscriptionOffer(
      id: 'opaque',
      productIdentifier: 'monthly',
      price: r'$4.99',
      period: SubscriptionPeriod.monthly,
    ),
  ];

  @override
  Future<SubscriptionDiagnostics> loadDiagnostics() async =>
      SubscriptionDiagnostics(availability: availability);

  @override
  Future<SubscriptionState> purchase(String offerId) async {
    purchasedOfferId = offerId;
    return refreshed;
  }

  @override
  Future<SubscriptionState> refresh() async => refreshed;

  @override
  Future<SubscriptionState> restore() async {
    restores++;
    if (restoreError != null) throw restoreError!;
    return restored;
  }

  @override
  Future<String?> updateIdentity(String? identity) async {
    identityUpdates.add(identity);
    return identity;
  }
}

class _PendingStore extends _FakeStore {
  _PendingStore(this.purchaseResult)
    : super(availability: SubscriptionAvailability.available);

  final Future<SubscriptionState> purchaseResult;

  @override
  Future<SubscriptionState> purchase(String offerId) => purchaseResult;
}

void main() {
  group('DefaultSubscriptionRepository', () {
    test('hydrates and replays cache before network refresh', () async {
      final repository = DefaultSubscriptionRepository(
        _FakeStore(),
        _FakeRemote(() async => _verifiedFree),
        _MemoryCache(_cachedPro),
      );
      addTearDown(repository.dispose);

      expect((await repository.hydrateFromCache())?.isPro, isTrue);
      expect(await repository.watchState().first, same(_cachedPro));
    });

    test('auth reset clears and publishes free state', () async {
      final cache = _MemoryCache(_cachedPro);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(),
        _FakeRemote(() async => _verifiedFree),
        cache,
      );
      addTearDown(repository.dispose);
      await repository.hydrateFromCache();

      await repository.resetForAuthChange();

      expect(cache.value, isNull);
      expect(repository.currentState?.isPro, isFalse);
      expect(repository.currentState?.origin, SubscriptionStateOrigin.auth);
    });

    test('verified free refresh clears cached Pro', () async {
      final cache = _MemoryCache(_cachedPro);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(),
        _FakeRemote(() async => _verifiedFree),
        cache,
      );
      addTearDown(repository.dispose);
      await repository.hydrateFromCache();

      final refreshed = await repository.refresh(force: true);

      expect(refreshed.isPro, isFalse);
      expect(cache.value, isNull);
      expect(cache.clears, 1);
    });

    test('transient refresh failure retains cached Pro', () async {
      final cache = _MemoryCache(_cachedPro);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(),
        _FakeRemote(() async => throw TimeoutException('offline')),
        cache,
      );
      addTearDown(repository.dispose);

      final refreshed = await repository.refresh(force: true);

      expect(refreshed.isPro, isTrue);
      expect(cache.value?.verifiedAt, _cachedPro.verifiedAt);
    });

    test('coalesces concurrent forced refreshes', () async {
      final response = Completer<SubscriptionState>();
      final remote = _FakeRemote(() => response.future);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(),
        remote,
        _MemoryCache(null),
      );
      addTearDown(repository.dispose);

      final first = repository.refresh(force: true);
      final second = repository.refresh(force: true);
      response.complete(_verifiedFree);
      await Future.wait([first, second]);

      expect(remote.fetches, 1);
    });

    test('purchases an opaque offer through the store data source', () async {
      final purchased = _cachedPro.copyWith(
        origin: SubscriptionStateOrigin.store,
        verification: SubscriptionVerification.verified,
      );
      final store = _FakeStore(
        availability: SubscriptionAvailability.available,
        refreshed: purchased,
      );
      final cache = _MemoryCache(null);
      final repository = DefaultSubscriptionRepository(
        store,
        _FakeRemote(() async => _verifiedFree),
        cache,
      );
      addTearDown(repository.dispose);

      final result = await repository.purchase('opaque-offer');

      expect(store.purchasedOfferId, 'opaque-offer');
      expect(result.isPro, isTrue);
      expect(cache.value?.isPro, isTrue);
    });

    test('restore verifies with entitlement GET and keeps store Pro', () async {
      final restored = _cachedPro.copyWith(
        origin: SubscriptionStateOrigin.store,
        verification: SubscriptionVerification.verified,
      );
      final remote = _FakeRemote(() async => _verifiedFree);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(
          availability: SubscriptionAvailability.available,
          restored: restored,
          refreshed: restored,
        ),
        remote,
        _MemoryCache(null),
      );
      addTearDown(repository.dispose);

      final result = await repository.restore();

      expect(result.isPro, isTrue);
      expect(remote.fetches, 1);
    });

    test('offline restore does not extend cached verification age', () async {
      final cache = _MemoryCache(_cachedPro);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(
          availability: SubscriptionAvailability.available,
          restoreError: TimeoutException('offline'),
        ),
        _FakeRemote(() async => _verifiedFree),
        cache,
      );
      addTearDown(repository.dispose);

      final result = await repository.restore();

      expect(result.origin, SubscriptionStateOrigin.offline);
      expect(result.verifiedAt, _cachedPro.verifiedAt);
      expect(cache.saves, 0);
    });

    test('store listener uses repository merge policy', () async {
      final store = _FakeStore(
        availability: SubscriptionAvailability.available,
      );
      final repository = DefaultSubscriptionRepository(
        store,
        _FakeRemote(() async => _verifiedFree),
        _MemoryCache(_cachedPro),
      );
      addTearDown(() async {
        await repository.dispose();
        await store.controller.close();
      });
      await repository.hydrateFromCache();
      repository.start();

      store.controller.add(_verifiedFree);
      await expectLater(
        repository.watchState(),
        emits(predicate<SubscriptionState>((state) => !state.isPro)),
      );
    });

    test(
      'identity update logs in store and links authoritative identity',
      () async {
        final store = _FakeStore();
        final remote = _FakeRemote(() async => _verifiedFree);
        final cache = _MemoryCache(_cachedPro);
        final repository = DefaultSubscriptionRepository(store, remote, cache);
        addTearDown(repository.dispose);

        await repository.updateIdentity('account-user');

        expect(store.identityUpdates, ['account-user']);
        expect(remote.linkedStoreIdentities, ['account-user']);
        expect(cache.value, isNull);
        expect(repository.currentState?.origin, SubscriptionStateOrigin.auth);
      },
    );

    test('account switch cannot accept an in-flight purchase', () async {
      final completer = Completer<SubscriptionState>();
      final repository = DefaultSubscriptionRepository(
        _PendingStore(completer.future),
        _FakeRemote(() async => _verifiedFree),
        _MemoryCache(null),
      );
      addTearDown(repository.dispose);

      final purchase = repository.purchase('monthly');
      await repository.resetForAuthChange();
      completer.complete(_cachedPro);

      await expectLater(
        purchase,
        throwsA(isA<SubscriptionAccountChangedException>()),
      );
      expect(repository.currentState?.isPro, isFalse);
    });

    test('expired offline cache removes paid access', () async {
      final cache = _MemoryCache(null);
      final repository = DefaultSubscriptionRepository(
        _FakeStore(),
        _FakeRemote(() async => _verifiedFree),
        cache,
      );
      addTearDown(repository.dispose);
      await repository.hydrateFromCache();
      cache.value = _cachedPro;
      await repository.hydrateFromCache();
      cache.value = null;

      final state = await repository.loadCachedState();

      expect(state?.isPro, isFalse);
      expect(state?.verification, SubscriptionVerification.unavailable);
    });
  });

  test('legacy entitlement id is canonicalized only by adapter mapping', () {
    const legacy = PremiumEntitlements(
      tier: BillingTier.pro,
      entitlementIds: ['pro'],
      billingConnected: true,
      source: 'revenuecat',
    );

    final mapped = LegacySubscriptionMapper.fromEntitlements(legacy);

    expect(mapped.entitlementIds, ['archive_loop_pro']);
    expect(mapped.origin, SubscriptionStateOrigin.store);
  });

  test('subscription state JSON round-trips every canonical origin', () {
    for (final origin in SubscriptionStateOrigin.values) {
      final state = SubscriptionState.free(origin: origin);

      expect(SubscriptionState.fromJson(state.toJson()).origin, origin);
    }
  });

  test('subscription state JSON accepts legacy source strings', () {
    expect(
      SubscriptionState.fromJson({
        ...SubscriptionState.free().toJson(),
        'source': 'auth_required',
      }).origin,
      SubscriptionStateOrigin.auth,
    );
    expect(
      SubscriptionState.fromJson({
        ...SubscriptionState.free().toJson(),
        'source': 'offline_cache_restore',
      }).origin,
      SubscriptionStateOrigin.offline,
    );
    expect(
      SubscriptionState.fromJson({
        ...SubscriptionState.free().toJson(),
        'source': 'revenuecat',
      }).origin,
      SubscriptionStateOrigin.store,
    );
  });

  test('subscription state migrates the previous Pro access-kind name', () {
    final state = SubscriptionState.fromJson({
      ..._cachedPro.toJson(),
      'accessKind': 'proSubscription',
    });

    expect(state.accessKind, PlanKind.pro);
    expect(state.isPro, isTrue);
  });
}
