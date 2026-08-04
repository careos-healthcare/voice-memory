import '../../services/analytics/analytics_catalog.dart';

/// The literal that stands in for every number no real user has produced yet.
///
/// A zero is a measurement claim. Absence of measurement is not a zero, so an
/// unmeasured field renders this string instead of `0`.
const String notYetMeasured = 'NOT YET MEASURED';

/// Real users observed to date.
///
/// Zero. Raising this is a deliberate edit made together with real analytics;
/// until then [ProductValidationReport] refuses to render any rate.
const int observedRealUserCount = 0;

/// Where a metric's numbers can actually come from.
///
/// Only [clientAnalytics] metrics are derivable from catalogued events. Billing
/// facts live in the store and provider back offices and no client event can
/// stand in for them.
enum ProductMetricDataSource { clientAnalytics, storeBilling, providerBilling }

/// Whether a metric is one of the validation questions or a supporting signal.
enum ProductMetricTier { core, supporting }

/// A single product-market validation metric.
///
/// [eventIds] and [propertyKeys] must be registered in [AnalyticsCatalog];
/// `test/product_metrics_test.dart` fails if any of them would be rejected, so
/// a metric here is derivable rather than aspirational.
final class ProductValidationMetric {
  const ProductValidationMetric({
    required this.id,
    required this.question,
    required this.eventIds,
    required this.propertyKeys,
    required this.formula,
    required this.dataSource,
    this.tier = ProductMetricTier.core,
  });

  final String id;
  final String question;
  final List<String> eventIds;
  final List<String> propertyKeys;
  final String formula;
  final ProductMetricDataSource dataSource;
  final ProductMetricTier tier;

  bool get isClientDerivable =>
      dataSource == ProductMetricDataSource.clientAnalytics;
}

/// The registry the dashboard is checked against.
abstract final class ProductValidationMetrics {
  /// Every V1 funnel event id this measurement plan depends on.
  static const List<String> funnelEventIds = [
    'first_capture_started',
    'first_capture_saved',
    'transcript_reviewed',
    'first_valid_observation_delivered',
    'interpretation_feedback_submitted',
    'second_entry_saved',
    'first_valid_comparison_delivered',
    'changes_opened',
    'change_thread_opened',
    'weekly_review_opened',
    'paywall_shown_after_value',
    'purchase_started',
    'purchase_completed',
    'restore_completed',
    'export_completed',
  ];

  static const List<ProductValidationMetric> all = [
    ProductValidationMetric(
      id: 'first_capture_completion',
      question: 'Does someone who starts a first capture finish saving it?',
      eventIds: [
        'first_capture_started',
        'first_capture_saved',
        'transcript_reviewed',
      ],
      propertyKeys: ['source_type', 'ui_origin', 'performance_duration_band'],
      formula:
          'people with first_capture_saved divided by people with '
          'first_capture_started',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'first_valid_observation_rate',
      question:
          'Does a saved first capture produce an evidence-backed '
          'observation?',
      eventIds: ['first_capture_saved', 'first_valid_observation_delivered'],
      propertyKeys: [
        'conclusion_kind',
        'evidence_count_band',
        'performance_duration_band',
      ],
      formula:
          'people with first_valid_observation_delivered divided by people '
          'with first_capture_saved',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'interpretation_accurate_rate',
      question:
          'When people rate an interpretation, how often do they call it '
          'accurate?',
      eventIds: ['interpretation_feedback_submitted'],
      propertyKeys: ['feedback_choice', 'evidence_count_band'],
      formula:
          'interpretation_feedback_submitted with feedback_choice=accurate '
          'divided by all interpretation_feedback_submitted',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'interpretation_miss_rate',
      question:
          'How often is an interpretation the wrong angle or too '
          'generic?',
      eventIds: ['interpretation_feedback_submitted'],
      propertyKeys: ['feedback_choice', 'conclusion_kind'],
      formula:
          'interpretation_feedback_submitted with feedback_choice in '
          '{wrong_angle, too_generic} divided by all '
          'interpretation_feedback_submitted',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'second_entry_within_72h',
      question: 'Does a first save lead to a second one inside three days?',
      eventIds: ['first_capture_saved', 'second_entry_saved'],
      propertyKeys: ['time_band', 'source_type'],
      formula:
          'people with second_entry_saved and time_band in {same_session, '
          'within_24h, within_72h} divided by people with first_capture_saved',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'first_comparison_within_7d',
      question: 'Does a second entry produce a first comparison inside a week?',
      eventIds: ['second_entry_saved', 'first_valid_comparison_delivered'],
      propertyKeys: ['time_band', 'evidence_count_band'],
      formula:
          'people with first_valid_comparison_delivered and time_band in '
          '{same_session, within_24h, within_72h, within_7d} divided by people '
          'with second_entry_saved',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'changes_reopen',
      question: 'Do people come back to Changes rather than open it once?',
      eventIds: [
        'changes_opened',
        'change_thread_opened',
        'weekly_review_opened',
      ],
      propertyKeys: ['ui_origin', 'change_count_bucket'],
      formula:
          'people with two or more changes_opened sessions divided by people '
          'with at least one changes_opened',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'paywall_after_value',
      question: 'Is the paywall reached only after an observation landed?',
      eventIds: [
        'first_valid_observation_delivered',
        'paywall_shown_after_value',
      ],
      propertyKeys: ['access_decision', 'subscription_state', 'ui_origin'],
      formula:
          'people with paywall_shown_after_value divided by people with '
          'first_valid_observation_delivered',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'purchase_conversion',
      question: 'Of the people who start a purchase, how many complete it?',
      eventIds: ['purchase_started', 'purchase_completed'],
      propertyKeys: ['subscription_state', 'access_decision'],
      formula:
          'people with purchase_completed divided by people with '
          'purchase_started',
      dataSource: ProductMetricDataSource.clientAnalytics,
    ),
    ProductValidationMetric(
      id: 'renewal_rate',
      question: 'Do paying people renew at the end of a period?',
      eventIds: [],
      propertyKeys: [],
      formula:
          'renewed subscriptions divided by subscriptions due to renew, from '
          'the store billing export only',
      dataSource: ProductMetricDataSource.storeBilling,
    ),
    ProductValidationMetric(
      id: 'refund_rate',
      question: 'How many purchases are refunded?',
      eventIds: [],
      propertyKeys: [],
      formula:
          'refunded purchases divided by completed purchases, from the store '
          'billing export only',
      dataSource: ProductMetricDataSource.storeBilling,
    ),
    ProductValidationMetric(
      id: 'provider_cost_per_active_user',
      question:
          'What do transcription and analysis providers cost per active '
          'person?',
      eventIds: [],
      propertyKeys: [],
      formula:
          'provider invoice total for the period divided by active accounts '
          'counted server side',
      dataSource: ProductMetricDataSource.providerBilling,
    ),
    ProductValidationMetric(
      id: 'provider_cost_per_paying_user',
      question: 'What do those providers cost per paying person?',
      eventIds: [],
      propertyKeys: [],
      formula:
          'provider invoice total for the period divided by paying accounts '
          'counted server side',
      dataSource: ProductMetricDataSource.providerBilling,
    ),
    ProductValidationMetric(
      id: 'restore_success',
      question: 'Can a paying person restore access on a new install?',
      eventIds: ['restore_completed'],
      propertyKeys: ['subscription_state', 'access_decision'],
      formula:
          'people with restore_completed and subscription_state=pro_active '
          'divided by people with restore_completed',
      dataSource: ProductMetricDataSource.clientAnalytics,
      tier: ProductMetricTier.supporting,
    ),
    ProductValidationMetric(
      id: 'export_completion',
      question: 'Do people who ask for an export receive one?',
      eventIds: ['export_completed'],
      propertyKeys: ['ui_origin', 'entry_count_bucket'],
      formula:
          'people with export_completed divided by people with at least one '
          'first_capture_saved',
      dataSource: ProductMetricDataSource.clientAnalytics,
      tier: ProductMetricTier.supporting,
    ),
  ];

  static List<ProductValidationMetric> get core =>
      all.where((metric) => metric.tier == ProductMetricTier.core).toList();

  /// Event ids referenced here that the catalog would reject. Always empty.
  static List<String> get uncataloguedEventIds => [
    for (final id in <String>{
      ...funnelEventIds,
      for (final metric in all) ...metric.eventIds,
    })
      if (AnalyticsCatalog.activationEvent(id) == null) id,
  ];

  /// Property keys referenced here that the catalog would reject. Always empty.
  static List<String> get unregisteredPropertyKeys => [
    for (final key in <String>{
      for (final metric in all) ...metric.propertyKeys,
    })
      if (!AnalyticsCatalog.propertySpecs.containsKey(key)) key,
  ];

  static ProductValidationMetric byId(String id) =>
      all.firstWhere((metric) => metric.id == id);
}

/// A rate produced by real observed people.
///
/// The constructor refuses a cohort of zero, a denominator of zero, and a
/// numerator larger than its denominator, so an empty cohort cannot be
/// rendered as `0`.
final class ProductMetricMeasurement {
  ProductMetricMeasurement({
    required this.metricId,
    required this.numerator,
    required this.denominator,
    required this.realUserCount,
  }) {
    if (realUserCount <= 0) {
      throw ArgumentError.value(
        realUserCount,
        'realUserCount',
        'a measurement needs at least one real user',
      );
    }
    if (denominator <= 0) {
      throw ArgumentError.value(
        denominator,
        'denominator',
        'an empty denominator is not a measurement of zero',
      );
    }
    if (numerator < 0 || numerator > denominator) {
      throw ArgumentError.value(
        numerator,
        'numerator',
        'must be between zero and the denominator',
      );
    }
  }

  final String metricId;
  final int numerator;
  final int denominator;
  final int realUserCount;

  /// Rendered as an explicit ratio so it can never be mistaken for a target.
  String get rendered => '$numerator of $denominator';
}

/// Renders the current value of every metric, honestly.
final class ProductValidationReport {
  ProductValidationReport({
    this.realUserCount = observedRealUserCount,
    Map<String, ProductMetricMeasurement> measurements = const {},
  }) : measurements = Map.unmodifiable(measurements) {
    if (realUserCount <= 0 && this.measurements.isNotEmpty) {
      throw ArgumentError(
        'measurements were supplied without any real user to produce them',
      );
    }
  }

  final int realUserCount;
  final Map<String, ProductMetricMeasurement> measurements;

  bool get hasRealUsers => realUserCount > 0;

  /// The value to print for [metricId]; [notYetMeasured] unless a real
  /// measurement exists.
  String valueFor(String metricId) =>
      measurements[metricId]?.rendered ?? notYetMeasured;
}
