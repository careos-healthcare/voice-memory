import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/theme/writing_canvas_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writing canvas ThemeData uses 1.7 leading and editorial inset', () {
    final light = AppTheme.light().extension<WritingCanvasTheme>();
    final dark = AppTheme.dark().extension<WritingCanvasTheme>();

    expect(light, isNotNull);
    expect(dark, isNotNull);
    expect(light!.textStyle.height, WritingCanvasTheme.lineHeight);
    expect(dark!.textStyle.height, WritingCanvasTheme.lineHeight);
    expect(light.contentPadding.vertical, 36);
    expect(
      VoiceMemoryTypography.writingCanvasStyle().height,
      WritingCanvasTheme.lineHeight,
    );
  });
}
