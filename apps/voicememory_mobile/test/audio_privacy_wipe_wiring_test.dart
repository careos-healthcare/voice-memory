import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all user-facing archive wipes use complete privacy controls', () {
    final dialog = File(
      'lib/widgets/security/wipe_local_archive_dialog.dart',
    ).readAsStringSync();
    final account = File(
      'lib/screens/delete_account_screen.dart',
    ).readAsStringSync();
    final controls = File(
      'lib/security/local_privacy_data_controls.dart',
    ).readAsStringSync();

    expect(
      dialog,
      contains('LocalPrivacyDataControls.instance().clearLocalArchive()'),
    );
    expect(
      account,
      contains('LocalPrivacyDataControls.instance().clearLocalArchive()'),
    );
    expect(account, contains('destroySanctuaryKeysAfterWipe()'));
    expect(controls, contains('auxiliaryAudioWipe:'));
    expect(controls, contains('wipeQueuedAudioData'));
  });
}
