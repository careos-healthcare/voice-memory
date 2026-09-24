import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Renders the memo headings, paragraphs, and bullet lines.
class LifeMemoMarkdown extends StatelessWidget {
  const LifeMemoMarkdown({required this.markdown, super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: AppTokens.spacing2));
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(
          Text(
            line.substring(3),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTokens.neutral900,
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('# ')) {
        blocks.add(
          Text(
            line.substring(2),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTokens.neutral900,
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('- ')) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(left: AppTokens.spacing3),
            child: Text(
              '• ${line.substring(2)}',
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                color: AppTokens.neutral800,
              ),
            ),
          ),
        );
        continue;
      }
      blocks.add(
        Text(
          line,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppTokens.neutral800,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}
