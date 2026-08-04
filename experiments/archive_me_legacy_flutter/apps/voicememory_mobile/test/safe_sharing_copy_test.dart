import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/safe_sharing/safe_sharing_copy.dart';
import 'package:voicememory_mobile/features/safe_sharing/safe_sharing_model.dart';

void main() {
  group('SafeSharingCopy', () {
    test('defines allowed canonical strings', () {
      expect(
        SafeSharingCopy.shareOnlyWhatYouChoose,
        'Share only what you choose.',
      );
      expect(
        SafeSharingCopy.privateReportExplainPattern,
        contains('someone you trust'),
      );
      expect(
        SafeSharingCopy.noDiagnosisDisclaimer,
        contains('does not diagnose'),
      );
      expect(SafeSharingCopy.userControlIncluded, contains('in control'));
      expect(
        SafeSharingCopy.futureSharingPrinciple,
        contains('explicit, private, and reversible'),
      );
    });

    test('safe copy contains consent/control language', () {
      expect(
        SafeSharingCopy.containsConsentLanguage(
          SafeSharingCopy.allVisibleStrings(),
        ),
        isTrue,
      );
    });

    test('safe copy contains no diagnosis/treatment/medical claims', () {
      expect(
        SafeSharingCopy.hasNoBannedTerms(SafeSharingCopy.allVisibleStrings()),
        isTrue,
      );
      for (final term in SafeSharingCopy.bannedTerms) {
        for (final line in SafeSharingCopy.allVisibleStrings()) {
          expect(
            line.toLowerCase(),
            isNot(contains(term)),
            reason: 'banned term "$term" found in "$line"',
          );
        }
      }
    });

    test('future feature is clearly labelled future/planned', () {
      expect(
        SafeSharingCopy.labelsFutureFeature(
          SafeSharingCopy.allVisibleStrings(),
        ),
        isTrue,
      );
      expect(
        SafeSharingCopy.futureFeatureLabel.toLowerCase(),
        anyOf(
          contains('planned'),
          contains('future'),
          contains('not available'),
        ),
      );
    });

    test('banned terms list matches spec', () {
      expect(SafeSharingCopy.bannedTerms, contains('therapy'));
      expect(SafeSharingCopy.bannedTerms, contains('therapist dashboard'));
      expect(SafeSharingCopy.bannedTerms, contains('clinical report'));
      expect(SafeSharingCopy.bannedTerms, contains('diagnosis'));
      expect(SafeSharingCopy.bannedTerms, contains('treatment'));
      expect(SafeSharingCopy.bannedTerms, contains('mental health assessment'));
      expect(SafeSharingCopy.bannedTerms, contains('medical record'));
      expect(SafeSharingCopy.bannedTerms, contains('care plan'));
      expect(SafeSharingCopy.bannedTerms, contains('doctor-ready diagnosis'));
    });
  });

  group('SafeSharingFoundation', () {
    test('build marks sharing as not live', () {
      final foundation = SafeSharingFoundation.build();
      expect(foundation.sharingLive, isFalse);
      expect(foundation.hasConsentCopy, isTrue);
      expect(foundation.hasFutureLabel, isTrue);
      expect(foundation.hasNoMedicalClaims, isTrue);
    });

    test('all visible strings pass copy guards', () {
      final foundation = SafeSharingFoundation.build();
      expect(
        SafeSharingCopy.containsConsentLanguage(foundation.allVisibleStrings),
        isTrue,
      );
      expect(
        SafeSharingCopy.hasNoBannedTerms(foundation.allVisibleStrings),
        isTrue,
      );
      expect(
        SafeSharingCopy.labelsFutureFeature(foundation.allVisibleStrings),
        isTrue,
      );
    });
  });

  group('Protected areas', () {
    test(
      'safe sharing foundation does not touch billing or protected integrations',
      () {
        const paths = [
          'lib/features/safe_sharing/safe_sharing_copy.dart',
          'lib/features/safe_sharing/safe_sharing_model.dart',
        ];
        for (final path in paths) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: path);
          final content = file.readAsStringSync().toLowerCase();
          expect(content, isNot(contains('revenuecat')));
          expect(content, isNot(contains('purchases_flutter')));
          expect(content, isNot(contains('productid')));
          expect(content, isNot(contains('entitlement')));
          expect(content, isNot(contains('journalservice')));
          expect(content, isNot(contains('proofthreshold')));
          expect(content, isNot(contains('openai')));
          expect(content, isNot(contains('contactspermission')));
          expect(content, isNot(contains('share_plus')));
        }
      },
    );

    test('no product integration beyond copy/model', () {
      expect(
        Directory('lib/features/safe_sharing').listSync().length,
        2,
        reason: 'only copy and model files expected',
      );
      expect(File('lib/widgets/safe_sharing').existsSync(), isFalse);
    });
  });
}
