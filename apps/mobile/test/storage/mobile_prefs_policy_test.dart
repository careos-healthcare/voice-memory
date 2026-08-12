import 'dart:io';

import 'package:archiveme_mobile/storage/mobile_prefs_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beta-scoped stores do not write personal content fields to prefs', () {
    const scopedSources = [
      'lib/features/activation/archive_insight_feedback.dart',
      'lib/features/pattern_naming/pattern_name_store.dart',
      'lib/features/proof_admission/remote_processing_consent_store.dart',
      'lib/features/early_archive/early_archive_insight_feedback_store.dart',
      'lib/features/onboarding/first_save_loop_store.dart',
      'lib/core/user/user_settings_store.dart',
    ];

    final violations = <String>[];
    for (final relative in scopedSources) {
      final file = File(relative);
      if (!file.existsSync()) continue;
      violations.addAll(
        MobilePrefsPolicy.violationsInSource(relative, file.readAsStringSync()),
      );
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('encrypted personal content keys are allowlisted', () {
    expect(
      MobilePrefsPolicy.encryptedPersonalContentKeys,
      contains('secure_archive_insight_correction_notes_v1'),
    );
  });
}
