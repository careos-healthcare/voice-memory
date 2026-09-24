import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// ThemeData tokens for the writing canvas — generous line height, editorial inset.
@immutable
class WritingCanvasTheme extends ThemeExtension<WritingCanvasTheme> {
  const WritingCanvasTheme({
    required this.textStyle,
    required this.contentPadding,
    this.idleRestore = const Duration(milliseconds: 1800),
  });

  static const lineHeight = 1.7;
  static const editorialLetterSpacing = 0.15;

  static const light = WritingCanvasTheme(
    textStyle: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: lineHeight,
      letterSpacing: editorialLetterSpacing,
      color: VoiceMemoryColors.textPrimary,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );

  static const dark = WritingCanvasTheme(
    textStyle: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: lineHeight,
      letterSpacing: editorialLetterSpacing,
      color: Color(0xFFF3F4F6),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );

  /// OLED canvas. Leading stays editorial; the inset uses the spacing scale.
  static const oled = WritingCanvasTheme(
    textStyle: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: lineHeight,
      letterSpacing: editorialLetterSpacing,
      color: Color(0xFFF2F2F2),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );

  final TextStyle textStyle;
  final EdgeInsets contentPadding;
  final Duration idleRestore;

  static WritingCanvasTheme of(BuildContext context) {
    return Theme.of(context).extension<WritingCanvasTheme>() ?? light;
  }

  @override
  WritingCanvasTheme copyWith({
    TextStyle? textStyle,
    EdgeInsets? contentPadding,
    Duration? idleRestore,
  }) {
    return WritingCanvasTheme(
      textStyle: textStyle ?? this.textStyle,
      contentPadding: contentPadding ?? this.contentPadding,
      idleRestore: idleRestore ?? this.idleRestore,
    );
  }

  @override
  WritingCanvasTheme lerp(ThemeExtension<WritingCanvasTheme>? other, double t) {
    if (other is! WritingCanvasTheme) return this;
    return WritingCanvasTheme(
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t) ?? textStyle,
      contentPadding:
          EdgeInsets.lerp(contentPadding, other.contentPadding, t) ??
          contentPadding,
      idleRestore: t < 0.5 ? idleRestore : other.idleRestore,
    );
  }
}
