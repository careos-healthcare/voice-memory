import 'dart:typed_data';

import 'package:archiveme_mobile/features/attachments/local_ocr_processor.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Image, note, and collapsible text extracted from that image.
class AttachmentViewerWidget extends StatefulWidget {
  const AttachmentViewerWidget({
    required this.transcript,
    required this.blocks,
    super.key,
    this.imageBytes,
    this.searchTerms = const [],
  });

  final Uint8List? imageBytes;
  final String transcript;
  final List<OcrTextBlock> blocks;
  final List<String> searchTerms;

  @override
  State<AttachmentViewerWidget> createState() => _AttachmentViewerWidgetState();
}

class _AttachmentViewerWidgetState extends State<AttachmentViewerWidget> {
  int? _openBlock;
  var _highlight = false;

  @override
  void initState() {
    super.initState();
    _highlight = widget.searchTerms.any((term) => term.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final open = _openBlock;
    final block = open == null ? null : widget.blocks[open];
    return Column(
      key: const Key('attachment_viewer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.imageBytes == null)
          const SizedBox(key: Key('attachment_image'), height: 120)
        else
          Image.memory(
            widget.imageBytes!,
            key: const Key('attachment_image'),
            height: 120,
            fit: BoxFit.contain,
          ),
        const SizedBox(height: AppTokens.spacing3),
        Text(widget.transcript, key: const Key('attachment_transcript')),
        const SizedBox(height: AppTokens.spacing3),
        ExpansionTile(
          key: const Key('attachment_extracted_text'),
          title: const Text('Extracted Text'),
          children: [
            Wrap(
              spacing: AppTokens.spacing2,
              children: [
                for (var index = 0; index < widget.blocks.length; index++)
                  ActionChip(
                    key: Key('attachment_ocr_chip_$index'),
                    label: Text(_chipLabel(widget.blocks[index].text)),
                    onPressed: () => setState(() => _openBlock = index),
                  ),
              ],
            ),
            if (block != null)
              GestureDetector(
                key: const Key('attachment_ocr_body'),
                onTap: () => setState(() => _highlight = !_highlight),
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.spacing3),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppTokens.neutral900),
                      children: attachmentHighlightSpans(
                        block.text,
                        widget.searchTerms,
                        active: _highlight,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _chipLabel(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= 28) return trimmed;
  return '${trimmed.substring(0, 28)}…';
}

/// Marks [terms] inside [text] when [active] is true.
List<TextSpan> attachmentHighlightSpans(
  String text,
  List<String> terms, {
  required bool active,
}) {
  if (!active || text.isEmpty) {
    return [TextSpan(text: text)];
  }
  final marks = List<bool>.filled(text.length, false);
  final lower = text.toLowerCase();
  for (final term in terms) {
    final needle = term.trim().toLowerCase();
    if (needle.isEmpty) continue;
    var start = 0;
    while (start < lower.length) {
      final found = lower.indexOf(needle, start);
      if (found < 0) break;
      for (var index = found; index < found + needle.length; index++) {
        marks[index] = true;
      }
      start = found + needle.length;
    }
  }
  final spans = <TextSpan>[];
  var index = 0;
  while (index < text.length) {
    final marked = marks[index];
    var end = index + 1;
    while (end < text.length && marks[end] == marked) {
      end++;
    }
    spans.add(
      TextSpan(
        text: text.substring(index, end),
        style: marked
            ? const TextStyle(backgroundColor: AppTokens.primary200)
            : null,
      ),
    );
    index = end;
  }
  return spans;
}
