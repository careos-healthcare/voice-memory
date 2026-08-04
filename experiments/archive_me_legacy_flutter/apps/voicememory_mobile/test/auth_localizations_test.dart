import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/auth/auth_trigger_rules.dart';
import 'package:voicememory_mobile/l10n/auth_copy_localizations.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every auth trigger resolves localized injected copy', () {
    for (final reason in AuthTriggerReason.values) {
      final copy = l10n.authTriggerCopy(reason);
      expect(copy.title, isNotEmpty, reason: '$reason title');
      expect(copy.lead, isNotEmpty, reason: '$reason lead');
      expect(copy.cta, isNotEmpty, reason: '$reason CTA');
    }
  });

  test('account authentication strings are generated from ARB', () {
    expect(l10n.accountAuthCreateTitle, 'Create your ArchiveMe account');
    expect(l10n.accountAuthEmailLabel, 'Email');
    expect(l10n.accountAuthResendCode, 'Resend code');
  });
}
