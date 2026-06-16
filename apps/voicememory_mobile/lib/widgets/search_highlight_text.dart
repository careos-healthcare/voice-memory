import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Highlights [query] matches inside [text] (case-insensitive).
class SearchHighlightText extends StatelessWidget {
  const SearchHighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ??
        const TextStyle(color: AppTheme.foreground, fontSize: 14, height: 1.35);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.amber.withValues(alpha: 0.35),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = index + trimmed.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}
