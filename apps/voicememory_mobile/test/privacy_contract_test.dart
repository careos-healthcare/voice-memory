import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/privacy_contract.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';

void main() {
  test('canonical privacy contract promises are non-empty and distinct', () {
    expect(PrivacyContract.canonicalPromises, isNotEmpty);
    expect(
      PrivacyContract.canonicalPromises.toSet().length,
      PrivacyContract.canonicalPromises.length,
    );
  });

  test('privacy copy policy aligns with journal encryption contract', () {
    expect(PrivacyCopyPolicy.journalEncryptedAtRest, contains('encrypted'));
    expect(
      PrivacyContract.journalEncryptedAtRest.toLowerCase(),
      contains('encrypted'),
    );
  });

  test('privacy copy policy does not claim never-sent globally', () {
    expect(
      PrivacyCopyPolicy.transcriptionAnalysisWhenUsed.toLowerCase(),
      isNot(contains('never sent')),
    );
  });
}
