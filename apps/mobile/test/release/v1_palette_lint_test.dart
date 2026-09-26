import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// V1 surfaces that must read `context.palette` instead of light-only tokens.
const v1PaletteFiles = <String>[
  'lib/features/capture_flow/ui/capture_screen.dart',
  'lib/features/capture_flow/ui/capture_screen_host.dart',
  'lib/features/capture_flow/ui/capture_flow_panels.dart',
  'lib/features/capture_flow/ui/routine_prompt_card.dart',
  'lib/features/capture_flow/ui/speech_language_choice_card.dart',
  'lib/features/capture_flow/ui/local_transcription_unavailable_card.dart',
  'lib/widgets/record/moment_save_receipt_card.dart',
  'lib/features/archive/v1/archive_dashboard_scroll_view.dart',
  'lib/screens/archive_belief_screen.dart',
  'lib/screens/entry_detail_screen.dart',
  'lib/screens/account_screen.dart',
  'lib/screens/onboarding_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/widgets/pushed_screen_shell.dart',
  'lib/widgets/main_shell.dart',
];

final _banned = RegExp(
  r'AppColors\.[A-Za-z]+|AppTheme\.(background|surface|muted|foreground|accent)\b',
);

void main() {
  test('V1-reachable files do not hard-code light colour tokens', () {
    final root = Directory.current.path.endsWith('apps/mobile')
        ? Directory.current
        : Directory('apps/mobile');
    final hits = <String>[];
    for (final relative in v1PaletteFiles) {
      final file = File('${root.path}/$relative');
      expect(file.existsSync(), isTrue, reason: relative);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_banned.hasMatch(lines[i])) {
          hits.add('$relative:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
