import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/revenue_foundation/revenue_value_copy.dart';
import 'package:voicememory_mobile/features/revenue_foundation/revenue_value_engine.dart';
import 'package:voicememory_mobile/features/revenue_foundation/revenue_value_model.dart';

void main() {
  group('RevenueValueCopy', () {
    test('differentiates from chat', () {
      expect(RevenueValueCopy.chatGptDifferentiationLine, contains('ChatGPT'));
      expect(RevenueValueCopy.comparesMomentsLine, contains('not a chat'));
      expect(
        RevenueValueCopy.positioningHeadline,
        contains('ArchiveMe shows what you already said before'),
      );
    });

    test('paid reason strings avoid more AI framing', () {
      final blob = [
        RevenueValueCopy.paidReasonBody,
        RevenueValueCopy.paidReasonEvidenceLine,
        RevenueValueCopy.longTermHistoryBody,
        RevenueValueCopy.privateReportBody,
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('more ai')));
      expect(blob, isNot(contains('smarter chat')));
      expect(blob, contains('first useful proof'));
      expect(blob, contains('private'));
    });

    test('safe sharing copy has no medical claims', () {
      final strings = [
        RevenueValueCopy.safeSharingBody,
        RevenueValueCopy.safeSharingDisclaimer,
        RevenueValueCopy.safeSharingChoice,
        RevenueValueCopy.safeSharingFutureNote,
      ];
      expect(RevenueValueEngine.hasNoMedicalClaims(strings), isTrue);
    });

    test('future sharing note is not presented as live', () {
      expect(
        RevenueValueCopy.safeSharingFutureNote.toLowerCase(),
        contains('future'),
      );
      expect(
        RevenueValueCopy.safeSharingFutureNote.toLowerCase(),
        contains('not available'),
      );
    });
  });

  group('RevenueValueEngine', () {
    test('build exposes value flags', () {
      final foundation = RevenueValueEngine.build();
      expect(foundation.hasClearPaidReason, isTrue);
      expect(foundation.longTermHistoryValue, isTrue);
      expect(foundation.privateReportValue, isTrue);
      expect(foundation.exportValue, isTrue);
      expect(foundation.safeSharingFutureValue, isTrue);
      expect(foundation.safeSharingLive, isFalse);
    });

    test('copy differentiates from chat', () {
      final foundation = RevenueValueEngine.build();
      expect(RevenueValueEngine.differentiatesFromChat(foundation), isTrue);
    });

    test('paid reason mentions archive history report not more AI', () {
      final foundation = RevenueValueEngine.build();
      expect(RevenueValueEngine.mentionsPaidMemoryNotAi(foundation), isTrue);
    });

    test('safe sharing copy has no medical claims', () {
      final foundation = RevenueValueEngine.build();
      expect(
        RevenueValueEngine.hasNoMedicalClaims(foundation.allVisibleStrings),
        isTrue,
      );
    });

    test('future features are not presented as live', () {
      final foundation = RevenueValueEngine.build();
      expect(
        RevenueValueEngine.futureFeaturesNotPresentedAsLive(foundation),
        isTrue,
      );
    });

    test('export planned copy when exportReportsLive is false', () {
      RevenueValueEngine.exportReportsLive = false;
      addTearDown(() => RevenueValueEngine.exportReportsLive = true);

      final foundation = RevenueValueEngine.build();
      expect(foundation.exportValue, isFalse);
      expect(foundation.exportBody.toLowerCase(), contains('planned'));
      expect(foundation.exportLabel.toLowerCase(), contains('planned'));
    });

    test('all consumer strings avoid banned medical terms', () {
      final strings = RevenueValueCopy.allConsumerStrings(
        exportReportsLive: true,
        safeSharingLive: false,
      );
      expect(RevenueValueEngine.hasNoMedicalClaims(strings), isTrue);
    });
  });

  group('Protected areas', () {
    test(
      'revenue foundation files do not touch billing or protected integrations',
      () {
        const paths = [
          'lib/features/revenue_foundation/revenue_value_copy.dart',
          'lib/features/revenue_foundation/revenue_value_model.dart',
          'lib/features/revenue_foundation/revenue_value_engine.dart',
        ];
        for (final path in paths) {
          final source = File(path).readAsStringSync().toLowerCase();
          expect(source.contains('revenuecat'), isFalse, reason: path);
          expect(source.contains('restorepurchases'), isFalse, reason: path);
          expect(source.contains('productid'), isFalse, reason: path);
          expect(source.contains('entitlement'), isFalse, reason: path);
          expect(source.contains('journalstore.save'), isFalse, reason: path);
          expect(source.contains('backend'), isFalse, reason: path);
          expect(source.contains('firebase'), isFalse, reason: path);
        }
      },
    );
  });
}
