import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// The promises used to live in `lib/security/privacy_contract.dart`, which no
// app code imported and whose encryption promise was a second assembly of the
// same two policy constants. They are now declared once, in the policy.
void main() {
  test('canonical privacy contract promises are non-empty and distinct', () {
    expect(PrivacyCopyPolicy.canonicalPromises, isNotEmpty);
    expect(
      PrivacyCopyPolicy.canonicalPromises.toSet().length,
      PrivacyCopyPolicy.canonicalPromises.length,
    );
  });

  test('privacy copy policy aligns with journal encryption contract', () {
    expect(PrivacyCopyPolicy.journalEncryptedAtRest, contains('encrypted'));
    expect(
      PrivacyCopyPolicy.journalEncryptedAtRestPromise.toLowerCase(),
      contains('encrypted'),
    );
  });

  test('the encryption promise is assembled, not written a second time', () {
    expect(
      PrivacyCopyPolicy.journalEncryptedAtRestPromise,
      contains(PrivacyCopyPolicy.encryptedAtRestScoped),
    );
    expect(
      PrivacyCopyPolicy.journalEncryptedAtRestPromise,
      contains(PrivacyCopyPolicy.encryptionBaselineDetail),
    );
  });

  test('privacy copy policy does not claim never-sent globally', () {
    expect(
      PrivacyCopyPolicy.transcriptionAnalysisWhenUsed.toLowerCase(),
      isNot(contains('never sent')),
    );
  });
}
