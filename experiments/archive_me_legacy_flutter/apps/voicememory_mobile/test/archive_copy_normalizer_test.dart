import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_copy_normalizer.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_display_copy_guard.dart';
import 'package:voicememory_mobile/features/patterns/pattern_display_copy_gate.dart';

import 'helpers/archive_approved_log_hygiene.dart';

void main() {
  group('ArchiveCopyNormalizer', () {
    test('normalizes youreally spacing', () {
      const raw =
          'You said youreally need it to work because you keep checking.';
      const fixed =
          'You said you really need it to work because you keep checking.';

      expect(ArchiveCopyNormalizer.normalize(raw), fixed);
      expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
    });

    test('normalizes ArchiveMeis spacing', () {
      const raw =
          'ArchiveMeis seeing the same pressure return in stronger words.';
      const fixed =
          'ArchiveMe is seeing the same pressure return in stronger words.';

      expect(ArchiveCopyNormalizer.normalize(raw), fixed);
      expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
    });

    test('normalizes comma spacing in next line', () {
      const raw =
          'Next time,notice whether the pressure arrives before you start.';
      const fixed =
          'Next time, notice whether the pressure arrives before you start.';

      expect(ArchiveCopyNormalizer.normalize(raw), fixed);
      expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
    });

    test('normalizes mayalso spacing', () {
      const raw =
          'You mayalso be testing whether you can finally feel reassured.';
      const fixed =
          'You may also be testing whether you can finally feel reassured.';

      expect(ArchiveCopyNormalizer.normalize(raw), fixed);
      expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
    });

    test('normalizes ArchiveMeshould spacing', () {
      const raw = 'ArchiveMeshould wait for one more signal before naming it.';
      const fixed =
          'ArchiveMe should wait for one more signal before naming it.';

      expect(ArchiveCopyNormalizer.normalize(raw), fixed);
      expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
    });

    test('normalizes thought-map glued phrases', () {
      expect(ArchiveCopyNormalizer.normalize('anothersign'), 'another sign');
      expect(
        ArchiveCopyNormalizer.normalize(
          'That thoughtturns into another check.',
        ),
        'That thought turns into another check.',
      );
      expect(
        ArchiveCopyNormalizer.normalize('The check istrying to create relief.'),
        'The check is trying to create relief.',
      );
      expect(
        ArchiveCopyNormalizer.normalize('to=reliefconnector=because'),
        'to=relief connector=because',
      );
      expect(
        ArchiveCopyNormalizer.normalize(
          'from=cost to=alternativeconnector=alternative',
        ),
        'from=cost to=alternative connector=alternative',
      );
      expect(ArchiveCopyNormalizer.normalize('checkwas'), 'check was');
      expect(ArchiveCopyNormalizer.normalize('trustit'), 'trust it');
      expect(
        ArchiveCopyNormalizer.normalize('existingthread'),
        'existing thread',
      );
      expect(ArchiveCopyNormalizer.normalize('aneed'), 'a need');
      expect(
        ArchiveCopyNormalizer.normalize('ArchiveMeisbasing this on:'),
        'ArchiveMe is basing this on:',
      );
      expect(
        ArchiveCopyNormalizer.normalize('The app needs towork properly.'),
        'The app needs to work properly.',
      );
      expect(
        ArchiveCopyNormalizer.normalize(
          'This helps ArchiveMe separateuseful checking from reassurance.',
        ),
        'This helps ArchiveMe separate useful checking from reassurance.',
      );
      for (final fixed in [
        'That thought turns into another check.',
        'The check is trying to create relief.',
        'another sign',
        'needs to work',
      ]) {
        expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
      }
    });

    test('normalizes return hook glued phrases', () {
      expect(
        ArchiveCopyNormalizer.normalize('Watch thistomorrow'),
        'Watch this tomorrow',
      );
      expect(
        ArchiveCopyNormalizer.normalize('Tomorrow, see ifit returns'),
        'Tomorrow, see if it returns',
      );
      expect(
        ArchiveCopyNormalizer.normalize('Tomorrow, noticewhat changed'),
        'Tomorrow, notice what changed',
      );
      expect(
        ArchiveCopyNormalizer.normalize('See whether pressurearrives early'),
        'See whether pressure arrives early',
      );
      expect(
        ArchiveCopyNormalizer.normalize('Does this returnnaturally today?'),
        'Does this return naturally today?',
      );
      for (final fixed in [
        'Watch this tomorrow',
        'Tomorrow, see if it returns',
        'Tomorrow, notice what changed',
      ]) {
        expect(ArchiveCopyNormalizer.hasResidualMalformedText(fixed), isFalse);
      }
    });

    test('normalize is idempotent', () {
      const raw = 'You said youreally need it to work.';
      final once = ArchiveCopyNormalizer.normalize(raw);
      expect(ArchiveCopyNormalizer.normalize(once), once);
    });

    test('detects residual malformed tokens after partial fix', () {
      expect(
        ArchiveCopyNormalizer.hasResidualMalformedText('still has youreally'),
        isTrue,
      );
    });
  });

  group('ArchiveDisplayCopyGuard grammar logging', () {
    test(
      'PatternDisplayCopyGate receives normalized text, not raw malformed text',
      () {
        const raw =
            'You said youreally need it to work because you keep checking.';
        const fixed =
            'You said you really need it to work because you keep checking.';

        final logs = <String>[];
        final previousDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          logs.add(message ?? '');
        };
        addTearDown(() => debugPrint = previousDebugPrint);

        ArchiveDisplayCopyGuard.passesGrammarGate(
          field: PatternDisplayField.evidence,
          text: raw,
        );

        assertNoMalformedApprovedArchiveLogs(logs);
        expect(
          logs.where(
            (line) => line.contains('ARCHIVEME_PATTERN_DISPLAY_COPY_CHECK'),
          ),
          isNotEmpty,
        );
        expect(
          logs.any((line) => line.contains('you really need it to work')),
          isTrue,
        );
        expect(ArchiveCopyNormalizer.normalize(raw), fixed);
      },
    );

    test('validateAndNormalize approves normalized contrast now line', () {
      const raw =
          'You said youreally need it to work because you keep checking.';
      final approved = ArchiveDisplayCopyGuard.validateAndNormalize(
        field: 'contrastNow',
        text: raw,
      );

      expect(approved, contains('you really need it to work'));
      expect(approved.toLowerCase(), isNot(contains('youreally')));
    });
  });
}
