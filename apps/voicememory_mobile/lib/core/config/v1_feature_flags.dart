/// Central V1 release feature flags — single switchboard for surface area.
///
/// [enableV1Only] is the master switch. When true, every non-core flag below
/// resolves to false regardless of its base toggle.
abstract final class V1FeatureFlags {
  V1FeatureFlags._();

  /// When true, non-core product surfaces stay hidden and router guards apply.
  static const bool enableV1Only = true;

  /// Base toggles for post-V1 rollout (ignored while [enableV1Only] is true).
  static const bool _enableThoughtMap = false;
  static const bool _enableAnalyst = false;
  static const bool _enableActionItems = false;
  static const bool _enableWidgets = false;
  static const bool _enableCustomReports = false;

  /// Pattern map surfaces (post-save card, archive links, `/pattern-map`).
  static bool get enableThoughtMap => enableV1Only ? false : _enableThoughtMap;

  /// Archive Analyst drawer entry and `/archive-analyst`.
  static bool get enableAnalyst => enableV1Only ? false : _enableAnalyst;

  /// Remember-this / action items settings row and `/action-items`.
  static bool get enableActionItems =>
      enableV1Only ? false : _enableActionItems;

  /// Home-screen widgets and today's-check objective chrome.
  static bool get enableWidgets => enableV1Only ? false : _enableWidgets;

  /// Weekly review, private reports, insight quality, range review.
  static bool get enableCustomReports =>
      enableV1Only ? false : _enableCustomReports;
}
