import 'package:archiveme_mobile/features/journal_entry/journal_entry_backlink_copy.dart';
import 'package:archiveme_mobile/features/journal_entry/journal_entry_backlink_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders entry transcript with tappable highlights for citable fact sentences.
class JournalEntryHighlightedTranscript extends StatefulWidget {
  const JournalEntryHighlightedTranscript({
    required this.text, required this.highlights, super.key,
    this.baseStyle,
  });

  final String text;
  final List<JournalEntryQuoteHighlight> highlights;
  final TextStyle? baseStyle;

  @override
  State<JournalEntryHighlightedTranscript> createState() =>
      _JournalEntryHighlightedTranscriptState();
}

class _JournalEntryHighlightedTranscriptState
    extends State<JournalEntryHighlightedTranscript> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _recognizers.clear();

    final style = widget.baseStyle ??
        const TextStyle(height: 1.45, color: AppTheme.foreground);
    final highlightStyle = style.copyWith(
      backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.18),
      fontWeight: FontWeight.w600,
      color: AppColors.accentPrimary,
    );

    if (widget.highlights.isEmpty) {
      return Text(
        widget.text,
        key: const Key('entry_detail_recorded_body'),
        style: style,
      );
    }

    final spans = _buildSpans(style, highlightStyle);
    return SelectableText.rich(
      TextSpan(children: spans),
      key: const Key('entry_detail_recorded_body'),
    );
  }

  List<InlineSpan> _buildSpans(TextStyle baseStyle, TextStyle highlightStyle) {
    final sorted = [...widget.highlights]
      ..sort((a, b) => a.start.compareTo(b.start));
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final highlight in sorted) {
      if (highlight.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.text.substring(cursor, highlight.start),
            style: baseStyle,
          ),
        );
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showHighlightTooltip(context, highlight);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: widget.text.substring(highlight.start, highlight.end),
          style: highlightStyle,
          recognizer: recognizer,
        ),
      );
      cursor = highlight.end;
    }

    if (cursor < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }

  void _showHighlightTooltip(
    BuildContext context,
    JournalEntryQuoteHighlight highlight,
  ) {
    final insight = highlight.linkedInsights.firstOrNull;
    if (insight == null) return;

    final message = JournalEntryBacklinkCopy.highlightTooltip(
      insightTitle: insight.title,
      band: insight.confidenceBand,
    );

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final target = renderBox.localToGlobal(Offset.zero);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        top: target.dy + 8,
        child: Material(
          color: AppColors.transparent,
          child: Center(
            child: Container(
              key: Key('entry_quote_highlight_tooltip_${highlight.start}'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }
}

extension _HighlightFirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}