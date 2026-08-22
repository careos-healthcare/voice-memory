import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/encryption_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EncryptionStatusCard shows SQLCipher status for this build', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: EncryptionStatusCard()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('encryption_status_card')), findsOneWidget);

    if (SecureSqliteLockService.encryptionEnabled) {
      expect(
        find.text(PrivacySecurityControlCenterCopy.encryptionActiveLabel),
        findsOneWidget,
      );
      expect(
        find.text(PrivacySecurityControlCenterCopy.encryptionActiveBadge),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('encryption_status_active_badge')),
        findsOneWidget,
      );
    } else {
      expect(
        find.text(PrivacySecurityControlCenterCopy.encryptionInactiveLabel),
        findsOneWidget,
      );
    }
  });
}
