import 'dart:io';

import 'package:archiveme_mobile/features/future_revenue_scope/future_revenue_scope_copy.dart';
import 'package:archiveme_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';
import 'package:archiveme_mobile/features/safe_sharing_future/safe_sharing_future_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProConversionAuditCopy', () {
    test('canonical pro trail promise is defined', () {
      expect(
        ProConversionAuditCopy.proTrailCanonical,
        'Free shows the first useful proof. Pro keeps the longer proof trail.',
      );
    });

    test('banned live claims block more ai storage and dashboard', () {
      expect(ProConversionAuditCopy.bannedLiveClaims, contains('more ai'));
      expect(ProConversionAuditCopy.bannedLiveClaims, contains('better ai'));
      expect(
        ProConversionAuditCopy.bannedLiveClaims,
        contains('unlimited answers'),
      );
      expect(ProConversionAuditCopy.bannedLiveClaims, contains('ai coach'));
      expect(
        ProConversionAuditCopy.bannedLiveClaims,
        contains('unlimited storage'),
      );
      expect(
        ProConversionAuditCopy.bannedLiveClaims,
        contains('life dashboard'),
      );
      expect(
        ProConversionAuditCopy.hasNoBannedLiveClaims(
          ProConversionAuditCopy.bannedLiveClaims,
        ),
        isFalse,
      );
      expect(
        ProConversionAuditCopy.hasNoBannedLiveClaims([
          ProConversionAuditCopy.proTrailCanonical,
        ]),
        isTrue,
      );
    });

    test('medical claims remain blocked', () {
      expect(
        ProConversionAuditCopy.hasNoMedicalClaims([
          'Free shows the first useful proof. Pro keeps the longer proof trail.',
        ]),
        isTrue,
      );
      expect(
        ProConversionAuditCopy.hasNoMedicalClaims(['clinical report']),
        isFalse,
      );
    });
  });

  group('Future revenue scope docs', () {
    test('docs list blocked future directions', () {
      final doc = File(
        'docs/architecture/future_revenue_scope.md',
      ).readAsStringSync().toLowerCase();
      for (final direction in FutureRevenueScopeCopy.futureDirections) {
        expect(doc, contains(direction), reason: direction);
      }
      expect(doc, contains('growth loop'));
    });
  });

  group('Safe sharing future V1 lock', () {
    test('sharing frozen line says not a V1 growth loop', () {
      expect(
        SafeSharingFutureCopy.sharingFrozenLine.toLowerCase(),
        contains('not a v1 growth loop'),
      );
    });
  });
}