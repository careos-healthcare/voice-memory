import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_feature_flags.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/router/v1_quarantine_redirects.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pattern exploration stays frozen', () {
    expect(V1CapabilityRegistry.patternExploration, isFalse);
    expect(PatternExplorationFeatureFlags.isEnabled, isFalse);
  });

  test('explore is on the V1 supporting allowlist, not quarantined', () {
    expect(
      V1RouteRegistry.supportingPaths,
      contains(RouteCatalog.explorePatterns),
    );
    expect(
      V1RouteRegistry.quarantinedExactPaths,
      isNot(contains(RouteCatalog.explorePatterns)),
    );
    expect(
      V1QuarantineRedirects.exactPaths,
      isNot(contains(RouteCatalog.explorePatterns)),
    );
  });
}
