import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/analytics/analytics_catalog.dart';
import 'package:voicememory_mobile/services/analytics/operational_analytics.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

void main() {
  setUp(ProductAnalytics.resetForTest);

  test(
    'every operational event is catalogued and provider-dispatchable',
    () async {
      final sent = <String>[];
      ProductAnalytics.installProviderForTest(
        (event, _) async => sent.add(event),
      );

      for (final event in OperationalAnalyticsEvent.values) {
        await ProductAnalytics.trackOperational(event);
      }

      expect(sent, hasLength(OperationalAnalyticsEvent.values.length));
      expect(sent, contains('original_save_completed'));
      expect(sent, contains('transcription_completed'));
      expect(sent, contains('interpretation_completed'));
      expect(sent, contains('retry_exhausted'));
      expect(sent, contains('vault_write_completed'));
      expect(sent, contains('sync_completed'));
      expect(sent, contains('recovery_completed'));
      expect(sent, contains('purchase_completed'));
      expect(sent, contains('restore_completed'));
      expect(sent, contains('deletion_completed'));
      expect(sent, contains('export_completed'));
    },
  );

  test('machine-readable analytics contract includes every operation', () {
    final manifest =
        jsonDecode(
              File(
                '../../config/product/archive_me_v1_analytics_events.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final events = (manifest['events']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map((event) => event['id'])
        .toSet();

    expect(
      events,
      containsAll(
        OperationalAnalyticsEvent.values.map(
          (event) => AnalyticsCatalog.operationalEvent(event).value,
        ),
      ),
    );
  });

  test('feature facades emit only bounded structural fields', () async {
    final sent = <({String event, Map<String, Object> parameters})>[];
    ProductAnalytics.installProviderForTest((event, parameters) async {
      sent.add((event: event, parameters: parameters));
    });

    await CaptureOperationalAnalytics.originalSaveCompleted(
      OperationalSource.voice,
      OperationalTimingBand.under1s,
    );
    await RetryOperationalAnalytics.exhausted(
      OperationalAttemptBand.thirdOrMore,
      OperationalFailureCategory.timeout,
    );
    await ExportOperationalAnalytics.completed(
      OperationalExportFormat.full,
      12,
    );

    expect(sent[0].parameters, {
      'operation_source': 'voice',
      'performance_duration_band': 'under_1s',
    });
    expect(sent[1].parameters, {
      'failure_reason_band': 'timeout',
      'attempt_band': 'third_or_more',
    });
    expect(sent[2].parameters, {'format': 'full', 'item_count_bucket': 'many'});
  });

  test('count is validated while the export record is constructed', () {
    expect(
      () => ExportOperationalAnalytics.completed(
        OperationalExportFormat.readable,
        -1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'all operational facades stay private through provider dispatch',
    () async {
      final dispatched = <({String event, Map<String, Object> parameters})>[];
      ProductAnalytics.installProviderForTest((event, parameters) async {
        dispatched.add((event: event, parameters: parameters));
      });

      await CaptureOperationalAnalytics.originalSaveCompleted(
        OperationalSource.voice,
        OperationalTimingBand.under500ms,
      );
      await TranscriptionOperationalAnalytics.completed(
        OperationalTimingBand.under1s,
      );
      await InterpretationOperationalAnalytics.completed(
        OperationalTimingBand.under2s,
      );
      await RetryOperationalAnalytics.exhausted(
        OperationalAttemptBand.thirdOrMore,
        OperationalFailureCategory.timeout,
      );
      await VaultOperationalAnalytics.writeCompleted(
        OperationalTimingBand.under500ms,
      );
      await SyncRecoveryOperationalAnalytics.recoveryCompleted();
      await ExportOperationalAnalytics.completed(
        OperationalExportFormat.full,
        1000,
      );
      await CommerceOperationalAnalytics.purchaseCompleted();
      await DeletionOperationalAnalytics.completed();

      final payload = jsonEncode([
        for (final item in dispatched)
          {'event': item.event, 'parameters': item.parameters},
      ]);
      for (final forbidden in [
        'fixture transcript: private deadline',
        'exact evidence quote',
        'private conclusion',
        'private correction',
        'AR1-PRIVATE-RECOVERY-CODE',
        'entry-private-id',
        'archive-private-id',
        '/private/audio/capture.wav',
      ]) {
        expect(payload, isNot(contains(forbidden)));
      }
      expect(dispatched, hasLength(9));
      final keys = dispatched.expand((item) => item.parameters.keys).toSet();
      for (final forbiddenKey in [
        'transcript',
        'evidence',
        'conclusion',
        'correction',
        'code',
        'id',
        'path',
      ]) {
        expect(keys, isNot(contains(forbiddenKey)));
      }
    },
  );
}
