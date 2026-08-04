import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/product_metrics/product_metrics_cohort_export.dart';
import 'package:voicememory_mobile/features/product_metrics/product_validation_metrics.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/analytics/analytics_catalog.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

const _dashboardPath = 'docs/FIRST25_METRICS_DASHBOARD.md';

/// Placed in every long-form field of the fixture archive. If any of it reaches
/// the cohort export, the export is leaking journal substance.
const _sentinel = 'ZzQqSentinelAlpha';

/// Planted in the short, token-shaped archive fields that an implementation
/// would be most tempted to copy straight through.
///
/// Unlike [_sentinel] this is a legal analytics token — lower case, snake safe,
/// no content marker — so the export validator would happily pass it along. The
/// absence assertion below is the only thing standing in its way.
const _tokenSentinel = 'zzqqfixturebeta';

/// Archive fields [_tokenSentinel] is stored in verbatim.
const _tokenSentinelFields = [
  'mood',
  'recurring theme',
  'capture context tag',
  'entry aboutness',
  'memory surfacing',
];

/// Archive fields the sentinel is planted in, each stored as
/// `sentinel field` so the assertion below covers them one by one.
const _sentinelFields = [
  'transcript',
  'text edit',
  'exact language pattern',
  'concrete observation',
  'repeated signal',
  'tension',
  'avoided area',
  'next action',
  'pattern marker',
  'conclusion statement',
  'conclusion reasoning',
  'uncertainty note',
  'evidence quote',
  'alternative statement',
  'alternative rationale',
  'next recording prompt',
  'correction note',
  'theory id',
  'provenance model',
  'revision',
  'thread label',
  'pack label',
  'audio vault reference',
];

/// Every token the export is allowed to emit.
Set<String> get _catalogueVocabulary => {
  ...AnalyticsCatalog.countBuckets,
  ...AnalyticsCatalog.flagValues,
  ...AnalyticsCatalog.timeBands,
  ...AnalyticsCatalog.feedbackChoices,
  ...AnalyticsCatalog.accessDecisions,
  ...AnalyticsCatalog.subscriptionStates,
  ...AnalyticsCatalog.performanceDurationBands,
  ...ProductValidationMetrics.funnelEventIds,
  ProductMetricsCohortExport.schemaName,
  // Capture source is a catalogued `source_type` token with no allowlist.
  'voice',
  'typed',
  'imported',
  'migrated',
};

Reflection _reflection(String text, List<String> evidenceEntryIds) =>
    Reflection(
      mood: _tokenSentinel,
      emotionalIntensity: 4,
      recurringThemes: const [_tokenSentinel],
      exactLanguagePattern: '$text exact language pattern',
      concreteObservation: '$text concrete observation',
      repeatedSignal: '$text repeated signal',
      tensionOrContradiction: '$text tension',
      avoidedOrVagueArea: '$text avoided area',
      nextSmallAction: '$text next action',
      patternObservations: ['$text pattern marker'],
      explainableConclusion: ExplainableConclusion(
        id: '$text-conclusion',
        statement: '$text conclusion statement',
        confidence: 72,
        reasoning: ['$text conclusion reasoning'],
        uncertaintyNote: '$text uncertainty note',
        evidence: [
          for (final entryId in evidenceEntryIds)
            TranscriptEvidenceCitation(
              entryId: entryId,
              quote: '$text evidence quote',
              startUtf16: 0,
              endUtf16: 4,
              role: TranscriptEvidenceRole.supporting,
              sourceType: EvidenceSourceType.voice,
              audioTimestampMs: 1234,
              audioVaultReference: '$text audio vault reference',
            ),
        ],
        alternatives: [
          ExplainableAlternative(
            statement: '$text alternative statement',
            rationale: '$text alternative rationale',
          ),
        ],
        provenance: ExplainableConclusionProvenance(
          source: 'model',
          generatedAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
          schemaVersion: ExplainableConclusion.schemaVersion,
          model: '$text provenance model',
          sourceRevision: '$text revision',
        ),
        kind: ExplainableInsightKind.pattern,
        nextRecordingPrompt: '$text next recording prompt',
        correctionNote: '$text correction note',
        theoryId: '$text theory id',
      ),
    );

SavedMoment _entry({
  required String text,
  required int index,
  required List<String> evidenceEntryIds,
  SavedMomentSource source = SavedMomentSource.voice,
}) {
  final createdAt = DateTime.utc(2026, 3, index + 1, 9);
  return SavedMoment(
    id: '$text-entry-$index',
    createdAt: createdAt,
    transcript: '$text transcript',
    durationSeconds: 97,
    reflection: _reflection(text, evidenceEntryIds),
    source: source,
    textEdits: [
      SavedMomentTextEdit(
        editedAt: createdAt,
        source: source,
        text: '$text text edit',
      ),
    ],
    archiveThreadId: '$text thread label',
    archivePackId: '$text pack label',
    captureContextTag: _tokenSentinel,
    entryAboutness: _tokenSentinel,
    memorySurfacing: _tokenSentinel,
    localAudioVaultRef: '$text audio vault reference',
  );
}

CohortParticipantSnapshot _participant(String text) =>
    CohortParticipantSnapshot(
      archive: [
        _entry(text: text, index: 0, evidenceEntryIds: ['$text-entry-0']),
        _entry(
          text: text,
          index: 1,
          evidenceEntryIds: ['$text-entry-0', '$text-entry-1'],
          source: SavedMomentSource.typed,
        ),
      ],
      subscriptionState: CohortSubscriptionState.proActive,
      reachedSteps: ProductFunnelStep.values.toSet(),
      changesOpenCount: 3,
      comparisonCount: 2,
      interpretationFeedback: CohortFeedbackChoice.wrongAngle,
      paywallAccessDecision: CohortAccessDecision.deniedProRequired,
      firstObservationLatency: const Duration(milliseconds: 1400),
      secondEntryDelay: const Duration(hours: 30),
      firstComparisonDelay: const Duration(days: 4),
    );

String _dashboard() => File(_dashboardPath).readAsStringSync();

String _section(String doc, String startHeading, String endHeading) {
  final start = doc.indexOf(startHeading);
  final end = doc.indexOf(endHeading);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $startHeading');
  expect(end, greaterThan(start), reason: 'missing $endHeading');
  return doc.substring(start, end);
}

List<List<String>> _metricRows(String doc) => [
  for (final line in _section(
    doc,
    '## 3. Metric registry',
    '## 4. Metric derivations',
  ).split('\n'))
    if (line.startsWith('| `'))
      line.split('|').map((cell) => cell.trim()).toList(growable: false),
];

List<String> _backticked(String cell) => [
  for (final match in RegExp(r'`([^`]+)`').allMatches(cell)) match.group(1)!,
];

void _collectStrings(Object? value, List<String> into) {
  if (value is String) {
    into.add(value);
  } else if (value is Map) {
    for (final entry in value.entries) {
      into.add(entry.key as String);
      _collectStrings(entry.value, into);
    }
  } else if (value is List) {
    for (final item in value) {
      _collectStrings(item, into);
    }
  }
}

String _sampleValue(String key) {
  final spec = AnalyticsCatalog.propertySpecs[key];
  expect(spec, isNotNull, reason: 'unregistered property key "$key"');
  final allowed = spec!.allowedValues;
  if (allowed != null) return allowed.first;
  return const {
    'source_type': 'voice',
    'ui_origin': 'post_save',
    'conclusion_kind': 'observation',
  }[key]!;
}

void main() {
  setUp(ProductAnalytics.resetForTest);

  group('cohort export carries no journal substance', () {
    test('no sentinel from the archive reaches the export', () {
      final export = ProductMetricsCohortExport.build(
        participants: [_participant(_sentinel)],
      );
      final encoded = export.toJsonString();

      expect(
        encoded.toLowerCase(),
        isNot(contains(_sentinel.toLowerCase())),
        reason:
            'the sentinel is planted in ${_sentinelFields.length} archive '
            'fields (${_sentinelFields.join(', ')}); finding it here means '
            'one of them leaked into cohort analysis data',
      );
      for (final field in _sentinelFields) {
        expect(
          encoded.toLowerCase(),
          isNot(contains('$_sentinel $field'.toLowerCase())),
        );
      }
      expect(
        encoded,
        isNot(contains(_tokenSentinel)),
        reason:
            'a token-shaped value from ${_tokenSentinelFields.join(', ')} '
            'reached the export; it is legal analytics grammar, so only this '
            'assertion catches it',
      );
      // Identifiers, timestamps, and raw numbers are substance too.
      expect(encoded, isNot(contains('entry-0')));
      expect(encoded, isNot(contains('entry-1')));
      expect(encoded, isNot(contains('-conclusion')));
      expect(encoded, isNot(contains('2026')));
      expect(encoded, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
      expect(encoded, isNot(contains('97')));
      expect(encoded, isNot(contains('1234')));
    });

    test('every emitted token belongs to the catalogued vocabulary', () {
      final export = ProductMetricsCohortExport.build(
        participants: [
          _participant(_sentinel),
          CohortParticipantSnapshot(
            archive: [
              _entry(text: 'plain', index: 0, evidenceEntryIds: const []),
            ],
            interpretationFeedback: CohortFeedbackChoice.accurate,
            paywallAccessDecision: CohortAccessDecision.allowed,
            firstObservationLatency: const Duration(milliseconds: 120),
            secondEntryDelay: const Duration(minutes: 5),
            secondEntryInSameSession: true,
            firstComparisonDelay: const Duration(days: 9),
          ),
        ],
      );
      final strings = <String>[];
      _collectStrings(export.toJson(), strings);

      for (final value in strings) {
        final isKey =
            AnalyticsCatalog.propertySpecs.containsKey(value) ||
            value.endsWith('_count_bucket') ||
            const {
              'schema',
              'schema_version',
              'no_user_text',
              'real_user_cohort',
              'participants',
              'funnel_steps',
              'first_observation_latency',
              'second_entry_latency',
              'first_comparison_latency',
              'interpretation_feedback',
              'paywall_access',
              'subscription_mix',
              'event',
            }.contains(value);
        expect(
          isKey || _catalogueVocabulary.contains(value),
          isTrue,
          reason: '"$value" is neither a catalogued key nor a catalogued value',
        );
      }
    });

    test('archives that differ only in text produce an identical export', () {
      final withSentinel = ProductMetricsCohortExport.build(
        participants: [_participant(_sentinel)],
      ).toJsonString();
      final withPlainText = ProductMetricsCohortExport.build(
        participants: [_participant('plain')],
      ).toJsonString();

      expect(withSentinel, withPlainText);
    });

    test('an empty cohort produces empty distributions, not zeros', () {
      final export = ProductMetricsCohortExport.build(participants: const []);
      final json = export.toJson();

      expect(json['participant_count_bucket'], 'none');
      expect(json['participants'], isEmpty);
      expect(json['funnel_steps'], isEmpty);
      expect(json['interpretation_feedback'], isEmpty);
      expect(json['paywall_access'], isEmpty);
      expect(json['subscription_mix'], isEmpty);
      expect(json['real_user_cohort'], '0');
    });

    test('the validator rejects substance, free text, and raw numbers', () {
      for (final payload in <Map<String, Object>>[
        {'transcript': 'anything'},
        {'topic_label': 'money'},
        {'entry_id': 'abc'},
        {'quote_count_bucket': 'one'},
        {
          'participants': <Object>['a raw string row'],
        },
        {
          'participants': <Object>[
            <String, Object>{'source_type': 'i felt low about work all week'},
          ],
        },
        {'entry_count_bucket': 'seventeen'},
        {'entry_count_bucket': 42},
        {'time_band': 'last tuesday'},
        {'feedback_choice': 'sort_of'},
        {'schema': 'some_other_schema'},
        {
          'funnel_steps': <Object>[
            <String, Object>{'event': 'transcript_opened'},
          ],
        },
      ]) {
        expect(
          () => ProductMetricsCohortExport.validate(payload),
          throwsStateError,
          reason: payload.keys.join(','),
        );
      }
    });
  });

  group('dashboard metrics map onto the analytics catalog', () {
    test('the registry itself is fully catalogued', () {
      expect(ProductValidationMetrics.uncataloguedEventIds, isEmpty);
      expect(ProductValidationMetrics.unregisteredPropertyKeys, isEmpty);
    });

    test('every dashboard row matches a registered metric definition', () {
      final rows = _metricRows(_dashboard());
      expect(rows, hasLength(ProductValidationMetrics.all.length));

      for (var i = 0; i < rows.length; i++) {
        final cells = rows[i];
        expect(cells, hasLength(8), reason: cells.join('|'));
        final metric = ProductValidationMetrics.all[i];
        expect(_backticked(cells[1]), [metric.id]);

        final events = _backticked(cells[2]);
        if (metric.eventIds.isEmpty) {
          expect(events, isEmpty);
          expect(cells[2].toLowerCase(), contains('none'));
        } else {
          expect(events, metric.eventIds);
        }
        for (final event in events) {
          expect(
            AnalyticsCatalog.activationEvent(event),
            isNotNull,
            reason: 'the catalog rejects dashboard event "$event"',
          );
        }

        final properties = _backticked(cells[3]);
        if (metric.propertyKeys.isEmpty) {
          expect(properties, isEmpty);
          expect(cells[3].toLowerCase(), contains('none'));
        } else {
          expect(properties, metric.propertyKeys);
        }
        for (final property in properties) {
          expect(
            AnalyticsCatalog.propertySpecs.containsKey(property),
            isTrue,
            reason: 'the catalog rejects dashboard property "$property"',
          );
        }
      }
    });

    test('every registered funnel event appears in the dashboard', () {
      final doc = _dashboard();
      for (final event in ProductValidationMetrics.funnelEventIds) {
        expect(
          AnalyticsCatalog.activationEvent(event),
          isNotNull,
          reason: event,
        );
        expect(
          doc,
          contains(event),
          reason:
              '$event is instrumented but '
              'unwatched by the dashboard',
        );
      }
    });

    test('each client metric survives the ProductAnalytics guard', () async {
      for (final metric in ProductValidationMetrics.all) {
        if (!metric.isClientDerivable) continue;
        for (final event in metric.eventIds) {
          await ProductAnalytics.trackActivation(
            event,
            parameters: {
              for (final key in metric.propertyKeys) key: _sampleValue(key),
            },
          );
        }
      }
      final emitted = ProductAnalytics.eventsForTest
          .map((record) => record.event)
          .toSet();
      for (final metric in ProductValidationMetrics.all) {
        if (!metric.isClientDerivable) continue;
        expect(emitted, containsAll(metric.eventIds), reason: metric.id);
      }
    });

    test('billing metrics claim no client event', () {
      for (final metric in ProductValidationMetrics.all) {
        if (metric.isClientDerivable) continue;
        expect(metric.eventIds, isEmpty, reason: metric.id);
        expect(metric.propertyKeys, isEmpty, reason: metric.id);
      }
    });
  });

  group('unmeasured fields are marked, never zeroed', () {
    test('every dashboard value cell reads NOT YET MEASURED', () {
      for (final cells in _metricRows(_dashboard())) {
        expect(cells[6], notYetMeasured, reason: cells[1]);
      }
    });

    test('the cohort table is unmeasured rather than zero', () {
      final cohort = _section(
        _dashboard(),
        '## 2. Real user cohort',
        '## 3. Metric registry',
      );
      for (final line in cohort.split('\n')) {
        if (!line.startsWith('| ') || line.startsWith('| Field')) continue;
        if (line.startsWith('|---')) continue;
        final cells = line.split('|').map((cell) => cell.trim()).toList();
        expect(cells[2], anyOf(notYetMeasured, '0 (zero)'), reason: cells[1]);
      }
      expect(cohort, contains('Real users to date | 0 (zero)'));
    });

    test('the document states plainly that there are no real users', () {
      final doc = _dashboard();
      expect(observedRealUserCount, 0);
      expect(doc, contains('Real users to date: 0 (zero)'));
      expect(doc, contains(notYetMeasured));
    });

    test('no rate is printed anywhere', () {
      expect(
        _dashboard(),
        isNot(contains('%')),
        reason: 'there is no real denominator yet, so there is no rate',
      );
    });

    test('nothing claims to be validated', () {
      final doc = _dashboard().toLowerCase();
      expect(
        RegExp(r'\bvalidated\b').allMatches(doc).length,
        RegExp(r'\b(?:not|never) validated\b').allMatches(doc).length,
      );
      expect(doc, contains('not validated'));
    });

    test('synthetic results are separated from real user metrics', () {
      final doc = _dashboard();
      final registry = _section(
        doc,
        '## 3. Metric registry',
        '## 4. Metric derivations',
      );
      final synthetic = _section(
        doc,
        '## 6. Synthetic test results',
        '## 7. Cohort export',
      );

      expect(registry.toLowerCase(), isNot(contains('synthetic')));
      expect(synthetic, contains('NOT USER EVIDENCE'));
      expect(synthetic, contains('test/product_metrics_test.dart'));
      expect(doc.indexOf('## 6. Synthetic'), greaterThan(doc.indexOf('## 3.')));
    });

    test('pre-registered thresholds are labelled as targets', () {
      final thresholds = _section(
        _dashboard(),
        '## 5. Pre-registered decision thresholds',
        '## 6. Synthetic test results',
      );
      expect(thresholds, contains('They are not observations'));
      expect(thresholds, isNot(contains(notYetMeasured)));
    });

    test('a report refuses to render a rate without real users', () {
      final empty = ProductValidationReport();
      expect(empty.hasRealUsers, isFalse);
      for (final metric in ProductValidationMetrics.all) {
        expect(empty.valueFor(metric.id), notYetMeasured);
      }

      expect(
        () => ProductValidationReport(
          measurements: {
            'purchase_conversion': ProductMetricMeasurement(
              metricId: 'purchase_conversion',
              numerator: 1,
              denominator: 2,
              realUserCount: 2,
            ),
          },
        ),
        throwsArgumentError,
      );
    });

    test('a measurement cannot be manufactured from an empty cohort', () {
      expect(
        () => ProductMetricMeasurement(
          metricId: 'purchase_conversion',
          numerator: 0,
          denominator: 0,
          realUserCount: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductMetricMeasurement(
          metricId: 'purchase_conversion',
          numerator: 0,
          denominator: 4,
          realUserCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductMetricMeasurement(
          metricId: 'purchase_conversion',
          numerator: 5,
          denominator: 4,
          realUserCount: 4,
        ),
        throwsArgumentError,
      );
    });

    test('an unmeasured metric stays unmeasured inside a real cohort', () {
      final report = ProductValidationReport(
        realUserCount: 5,
        measurements: {
          'first_capture_completion': ProductMetricMeasurement(
            metricId: 'first_capture_completion',
            numerator: 3,
            denominator: 5,
            realUserCount: 5,
          ),
        },
      );

      expect(report.valueFor('first_capture_completion'), '3 of 5');
      expect(report.valueFor('renewal_rate'), notYetMeasured);
      expect(report.valueFor('provider_cost_per_active_user'), notYetMeasured);
    });
  });

  group('analytics privacy assertions for the validation funnel', () {
    test('sensitive keys are rejected for every funnel event', () {
      for (final event in ProductValidationMetrics.funnelEventIds) {
        for (final key in const [
          'transcript',
          'topic_label',
          'prompt_text',
          'entry_id',
          'memory_id',
          'customer_id',
          'email',
          'timestamp',
          'content_hash',
        ]) {
          expect(
            () => ProductAnalytics.trackActivation(
              event,
              parameters: {key: 'safe'},
            ),
            throwsStateError,
            reason: '$event/$key',
          );
        }
      }
    });

    test('free text and raw numbers are rejected for every funnel event', () {
      for (final event in ProductValidationMetrics.funnelEventIds) {
        expect(
          () => ProductAnalytics.trackActivation(
            event,
            parameters: const {'conclusion_kind': 'I felt low about work'},
          ),
          throwsStateError,
          reason: event,
        );
        expect(
          () => ProductAnalytics.trackActivation(
            event,
            parameters: const {'ui_origin': 'ZzQqSentinelAlpha'},
          ),
          throwsStateError,
          reason: event,
        );
        expect(
          () => ProductAnalytics.trackActivation(
            event,
            parameters: const {'time_band': 172800},
          ),
          throwsStateError,
          reason: event,
        );
        expect(
          () => ProductAnalytics.trackActivation(
            event,
            parameters: const {'feedback_choice': 'mostly_right'},
          ),
          throwsStateError,
          reason: event,
        );
      }
    });

    test('the content-marker exemption stays one event wide', () {
      expect(
        AnalyticsCatalog.activationEvent('transcript_reviewed'),
        isNotNull,
      );
      for (final event in const [
        'transcript_opened',
        'transcript_saved',
        'transcript_edited',
        'journal_reviewed',
        'quote_reviewed',
        'correction_reviewed',
        'reflection_reviewed',
        'private_reviewed',
        'content_reviewed',
      ]) {
        expect(
          AnalyticsCatalog.activationEvent(event),
          isNull,
          reason: '$event must not inherit the transcript_reviewed exemption',
        );
      }
    });

    test('funnel property values stay inside their allowlists', () {
      for (final key in const [
        'performance_duration_band',
        'time_band',
        'feedback_choice',
        'access_decision',
        'subscription_state',
        'evidence_count_band',
      ]) {
        final spec = AnalyticsCatalog.propertySpecs[key];
        expect(spec?.allowedValues, isNotNull, reason: key);
        for (final value in spec!.allowedValues!) {
          expect(AnalyticsCatalog.isSafeToken(value), isTrue, reason: value);
        }
      }
      expect(
        AnalyticsCatalog.durationBand(const Duration(milliseconds: 1400)),
        'under_2s',
      );
      expect(
        AnalyticsCatalog.performanceDurationBands.contains(
          AnalyticsCatalog.durationBand(const Duration(minutes: 3)),
        ),
        isTrue,
      );
    });
  });
}
