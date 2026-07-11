import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

const _bannedTerms = [
  'diagnosis',
  'treatment',
  'therapy',
  'clinical',
  'medical report',
  'cloud backup included',
  'sync is active',
  'your archive is backed up',
  'better ai',
  'more ai',
  'guaranteed transformation',
  'live backup',
];

void main() {
  group('ArchivePaywallCopy purchase confidence strings', () {
    test('defines loading, purchase, and restore clarity copy', () {
      expect(
        ArchivePaywallCopy.checkingProAccess,
        'Checking your Pro access…',
      );
      expect(
        ArchivePaywallCopy.purchaseStarting,
        'Starting secure purchase…',
      );
      expect(
        ArchivePaywallCopy.purchaseSuccess,
        'Pro is active. ArchiveMe keeps the longer proof trail over time.',
      );
      expect(
        ArchivePaywallCopy.restoreChecking,
        'Checking for previous purchases…',
      );
      expect(
        ArchivePaywallCopy.restoreSuccess,
        'Purchase restored. Pro is active.',
      );
      expect(
        ArchivePaywallCopy.restoreEmpty,
        'No previous Pro purchase was found on this Apple ID.',
      );
      expect(ArchivePaywallCopy.primaryCta, 'Keep the longer trail');
    });

    test('restore copy constants stay aligned with paywall confidence copy', () {
      expect(
        RestorePurchasesCopy.purchaseRestored,
        ArchivePaywallCopy.restoreSuccess,
      );
      expect(
        RestorePurchasesCopy.noActivePurchase,
        ArchivePaywallCopy.restoreEmpty,
      );
    });

    test('purchase confidence copy guard blocks banned terms', () {
      final blob =
          ArchivePaywallCopy.purchaseConfidenceCopy.join(' ').toLowerCase();
      for (final banned in _bannedTerms) {
        if (banned == 'therapy') continue;
        expect(blob, isNot(contains(banned)), reason: 'must not contain $banned');
      }
      expect(blob, contains('not therapy'));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
    });
  });

  group('PaywallScreen purchase confidence wiring', () {
    test('paywall screen references purchase confidence copy', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('ArchivePaywallCopy.checkingProAccess'));
      expect(source, contains('ArchivePaywallCopy.purchaseStarting'));
      expect(source, contains('ArchivePaywallCopy.purchaseSuccess'));
      expect(source, contains('ArchivePaywallCopy.restoreChecking'));
      expect(source, contains('ArchivePaywallCopy.proActiveConfirmation'));
      expect(source, contains('_PaywallBusyKind.purchase'));
      expect(source, contains('_PaywallBusyKind.restore'));
      expect(
        source,
        contains('sourceCopy?.cta ?? ConsumerUiCopy.paywallPrimaryCta'),
      );
    });
  });
}
