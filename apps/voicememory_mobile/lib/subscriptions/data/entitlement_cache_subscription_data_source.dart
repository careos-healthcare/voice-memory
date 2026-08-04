import '../../features/monetization/data/monetization_local_migration.dart';
import '../../storage/entitlement_cache.dart';
import '../domain/subscription_models.dart';
import 'legacy_subscription_mapper.dart';
import 'subscription_data_sources.dart';

class EntitlementCacheSubscriptionDataSource
    implements SubscriptionCacheDataSource {
  const EntitlementCacheSubscriptionDataSource(
    this._cache, [
    this._monetizationMigration,
  ]);

  final EntitlementCache _cache;
  final MonetizationLocalMigration? _monetizationMigration;

  @override
  Future<SubscriptionState?> load() async {
    final cached = await _cache.load();
    if (cached == null) return null;
    final state = LegacySubscriptionMapper.fromEntitlements(cached);
    await _monetizationMigration?.run(subscription: state);
    return state;
  }

  @override
  Future<void> save(SubscriptionState state) async {
    await _cache.save(LegacySubscriptionMapper.toEntitlements(state));
    await _monetizationMigration?.run(subscription: state);
  }

  @override
  Future<void> clear() => _cache.clear();
}
