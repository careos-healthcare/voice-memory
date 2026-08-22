/// Deliberately invalid CTA examples for route-link gate tests only.
/// Marker: PRODUCTION_ROUTE_LINK_FIXTURE — excluded from production scans.
abstract final class ProhibitedRouteLinkFixtureExamples {
  ProhibitedRouteLinkFixtureExamples._();

  static const examples = [
    // PRODUCTION_ROUTE_LINK_FIXTURE
    "onTap: () => context.push('/archive-export'),",
    // PRODUCTION_ROUTE_LINK_FIXTURE
  ];
}
