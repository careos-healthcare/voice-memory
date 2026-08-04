import '../product_analytics.dart';
import 'v1_composition_config.dart';

final class AnalyticsServices {
  AnalyticsServices._(this._config);

  final V1CompositionConfig _config;
  bool _activated = false;

  /// True once the analytics provider is live.
  bool get isActivated => _activated;

  /// Registers the module without starting the provider.
  ///
  /// `ProductAnalytics` queues catalogued events while no provider exists and
  /// flushes them on initialize, so deferring provider start-up loses nothing.
  static AnalyticsServices create(V1CompositionConfig config) =>
      AnalyticsServices._(config);

  Future<void> activate() async {
    if (_activated) return;
    if (!_config.testMode) await ProductAnalytics.initialize();
    _activated = true;
  }
}
