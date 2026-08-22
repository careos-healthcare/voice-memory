import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_beta_reducer.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_beta_reducer_copy.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_minimum_set.dart';
import 'package:flutter_test/flutter_test.dart';

const _docsPath = 'docs/CORE_METRICS_BETA_REDUCER.md';
const _reducerPath =
    'lib/features/core_metrics_minimum/core_metrics_beta_reducer.dart';
const _minimumSetPath =
    'lib/features/core_metrics_minimum/core_metrics_minimum_set.dart';

void main() {
  group('CoreMetricsBetaReducer.build', () {
    test('defines thirteen core beta decision metrics', () {
      final result = CoreMetricsBetaReducer.build();
      expect(result.coreMetricCount, 13);
      expect(result.metrics.length, 13);
      expect(result.decisionMetrics.length, 10);
      expect(result.revenueMetrics.length, 2);
      expect(result.releaseBlockingMetrics.length, 1);
    });
  });

  group('CoreMetricsBetaReducer.classifyMetric', () {
    test('core metrics classify as decisionMetric', () {
      for (final metricId in CoreMetricsBetaReducer.decisionMetricIds) {
        final result = CoreMetricsBetaReducer.classifyMetric(metricId);
        expect(result.isDecisionMetric, isTrue, reason: metricId.name);
        expect(result.diagnosticOnly, isFalse);
        expect(result.notDecisionMetric, isFalse);
        expect(result.notReleaseBlocking, isTrue);
      }
    });

    test('purchase metrics classify as revenueMetric', () {
      for (final metricId in CoreMetricsBetaReducer.revenueMetricIds) {
        final result = CoreMetricsBetaReducer.classifyMetric(metricId);
        expect(result.isRevenueMetric, isTrue, reason: metricId.name);
        expect(result.diagnosticOnly, isFalse);
        expect(result.notDecisionMetric, isTrue);
        expect(result.notReleaseBlocking, isTrue);
      }
    });

    test('crash/blocker classifies as releaseBlocking', () {
      final result = CoreMetricsBetaReducer.classifyMetric(
        CoreMetricsBetaMetricId.crashOrBlocker,
      );
      expect(result.isReleaseBlocking, isTrue);
      expect(result.diagnosticOnly, isFalse);
      expect(result.notDecisionMetric, isTrue);
      expect(result.notReleaseBlocking, isFalse);
    });
  });

  group('CoreMetricsBetaReducer.classifyActivationCounter', () {
    final diagnosticCounters = [
      'recordScreenSeen',
      'thirdMomentSaved',
      'twoEntryRelatedSeen',
      'paywallSeen',
      'restoreTapped',
    ];

    for (final counter in diagnosticCounters) {
      test('$counter -> diagnosticOnly', () {
        final result = CoreMetricsBetaReducer.classifyActivationCounter(
          counter,
        );
        expect(result.diagnosticOnly, isTrue);
        expect(result.notDecisionMetric, isTrue);
        expect(result.notReleaseBlocking, isTrue);
        expect(result.coreMetricId, isNull);
      });
    }

    test('appOpened counter maps to decision metric', () {
      final result = CoreMetricsBetaReducer.classifyActivationCounter(
        'appOpened',
      );
      expect(result.isDecisionMetric, isTrue);
      expect(result.coreMetricId, CoreMetricsBetaMetricId.appOpened);
    });
  });

  group('CoreMetricsBetaReducer.classifyEvent', () {
    test('purchase_started -> revenueMetric', () {
      final result = CoreMetricsBetaReducer.classifyEvent('purchase_started');
      expect(result.isRevenueMetric, isTrue);
      expect(result.coreMetricId, CoreMetricsBetaMetricId.purchaseStarted);
    });

    test('crash_blocker_reported -> releaseBlocking', () {
      final result = CoreMetricsBetaReducer.classifyEvent(
        'crash_blocker_reported',
      );
      expect(result.isReleaseBlocking, isTrue);
      expect(result.coreMetricId, CoreMetricsBetaMetricId.crashOrBlocker);
    });

    test('thread_return_evidence_seen -> diagnosticOnly', () {
      final result = CoreMetricsBetaReducer.classifyEvent(
        'thread_return_evidence_seen',
      );
      expect(result.diagnosticOnly, isTrue);
      expect(result.notDecisionMetric, isTrue);
    });

    test(
      'restore_started stays diagnostic because restore tapped is not core',
      () {
        final result = CoreMetricsBetaReducer.classifyEvent('restore_started');
        expect(result.diagnosticOnly, isTrue);
        expect(result.notDecisionMetric, isTrue);
      },
    );

    test('restore_completed -> decision metric', () {
      final result = CoreMetricsBetaReducer.classifyEvent('restore_completed');
      expect(result.isDecisionMetric, isTrue);
      expect(result.coreMetricId, CoreMetricsBetaMetricId.restoreSucceeded);
    });

    test('proof accepted event -> decision metric', () {
      final result = CoreMetricsBetaReducer.classifyEvent(
        'beta_proof_feedback_answered',
        properties: {'feedback_type': 'useful'},
      );
      expect(result.isDecisionMetric, isTrue);
      expect(result.coreMetricId, CoreMetricsBetaMetricId.proofAccepted);
    });
  });

  group('protected regression', () {
    late String reducerSource;
    late String minimumSetSource;

    setUpAll(() {
      reducerSource = File(_reducerPath).readAsStringSync();
      minimumSetSource = File(_minimumSetPath).readAsStringSync();
    });

    test('docs describe classify-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('do not delete analytics'));
      expect(doc, contains('do not stop existing analytics'));
      expect(doc, contains('classify only'));
      expect(doc, contains('beta decisions must use core metrics only'));
    });

    test('guardrail forbids analytics deletion', () {
      final guardrail = CoreMetricsBetaReducerCopy.guardrail.toLowerCase();
      expect(guardrail, contains('do not delete analytics'));
      expect(guardrail, contains('do not stop existing analytics'));
    });

    test('no analytics deletion', () {
      final forbiddenCalls = [
        '.deleteAnalytics(',
        '.removeAnalytics(',
        '.clearAnalytics(',
        '.stopAnalytics(',
      ];
      expect(forbiddenCalls.any(reducerSource.contains), isFalse);
      expect(
        CoreMetricsBetaReducer.detectMinimumClassifierPreserved(
          minimumSetSource,
        ),
        isTrue,
      );
      expect(CoreMetricsMinimumSet.classify('app_opened').isCoreBeta, isTrue);
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in CoreMetricsBetaReducerCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import billing or purchases_flutter', () {
      for (final path in [
        _reducerPath,
        'lib/features/core_metrics_minimum/core_metrics_beta_reducer_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });
  });
}