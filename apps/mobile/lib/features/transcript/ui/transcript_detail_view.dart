import 'dart:async';

import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_panel.dart';
import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_service.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_prompts.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/paywall_view.dart';
import 'package:archiveme_mobile/features/transcript/ui/transcript_markup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raw transcript plus Smart Summary, Action Items, and Diary Format.
///
/// Free accounts keep the transcript and see a premium prompt. An active
/// `pro` or `archive_loop_pro` entitlement runs the local Gemma rewrite.
class TranscriptDetailView extends StatefulWidget {
  const TranscriptDetailView({
    required this.entryId,
    required this.transcript,
    super.key,
    this.service,
    this.coach,
    this.showRawTranscript = true,
    this.bodyKey = const Key('entry_detail_recorded_body'),
  });

  final String entryId;
  final String transcript;
  final GemmaSummaryService? service;
  final AskTheCoachService? coach;
  final bool showRawTranscript;
  final Key bodyKey;

  @override
  State<TranscriptDetailView> createState() => _TranscriptDetailViewState();
}

class _TranscriptDetailViewState extends State<TranscriptDetailView> {
  GemmaSummaryStyle? _pendingStyle;
  String? _text;
  var _deferred = false;
  var _running = false;
  var _locked = false;
  TextSelection? _selection;
  final _tag = TextEditingController();
  final _phrase = TextEditingController();
  late final TranscriptMarkup _markup = TranscriptMarkup(widget.entryId);

  @override
  void dispose() {
    _tag.dispose();
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcript = widget.transcript.trim();
    if (transcript.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showRawTranscript)
          SelectableText(
            transcript,
            key: widget.bodyKey,
            style: const TextStyle(height: 1.45),
            onSelectionChanged: (selection, _) {
              setState(() => _selection = selection);
            },
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _button(
              key: const Key('gemma_summary_smart'),
              label: 'Smart summary',
              style: GemmaSummaryStyle.smartSummary,
            ),
            _button(
              key: const Key('gemma_summary_actions'),
              label: 'Action items',
              style: GemmaSummaryStyle.actionItems,
            ),
            _button(
              key: const Key('gemma_summary_diary'),
              label: 'Diary format',
              style: GemmaSummaryStyle.diaryFormat,
            ),
          ],
        ),
        if (_locked) ...[
          const SizedBox(height: 8),
          const Text(
            'Premium includes Smart summary, Action items, and custom formatting. The raw transcript stays here.',
            key: Key('gemma_summary_locked'),
          ),
          TextButton(
            key: const Key('gemma_summary_paywall'),
            onPressed: _openPaywall,
            child: const Text('See premium'),
          ),
        ],
        if (_deferred) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('gemma_summary_force'),
            onPressed: _pendingStyle == null
                ? null
                : () => _run(_pendingStyle!, forceImmediate: true),
            child: const Text('Generate now'),
          ),
        ],
        if (_text != null && _text!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_text!, key: const Key('gemma_summary_text')),
        ],
        const SizedBox(height: 8),
        TextField(
          key: const Key('transcript_phrase_input'),
          controller: _phrase,
          decoration: const InputDecoration(hintText: 'Highlight a phrase'),
        ),
        TextField(
          key: const Key('transcript_tag_input'),
          controller: _tag,
          decoration: const InputDecoration(hintText: 'Tag'),
        ),
        TextButton(
          key: const Key('transcript_save_clip'),
          onPressed: _saveClip,
          child: const Text('Save clip'),
        ),
        for (final clip in _markup.clips)
          Text(clip.shareText, key: Key('transcript_clip_${clip.start}')),
        if (widget.coach != null) ...[
          const SizedBox(height: 16),
          AskTheCoachPanel(service: widget.coach!),
        ],
      ],
    );
  }

  void _saveClip() {
    final transcript = widget.transcript;
    final selection = _selection;
    var start = 0;
    var end = 0;
    if (selection != null && selection.isValid && !selection.isCollapsed) {
      start = selection.start;
      end = selection.end;
    } else {
      final phrase = _phrase.text.trim();
      final index = phrase.isEmpty ? -1 : transcript.indexOf(phrase);
      if (index < 0) return;
      start = index;
      end = index + phrase.length;
    }
    final clip = _markup.saveClip(
      transcript: transcript,
      start: start,
      end: end,
      tags: _tag.text.split(','),
    );
    if (clip == null || !mounted) return;
    setState(() {
      _tag.clear();
      _phrase.clear();
    });
  }

  Widget _button({
    required Key key,
    required String label,
    required GemmaSummaryStyle style,
  }) {
    return TextButton(
      key: key,
      onPressed: _running ? null : () => _run(style),
      child: Text(label),
    );
  }

  PremiumEntitlement _entitlement() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(premiumEntitlementProvider);
    } on Object {
      return PremiumAccess.current;
    }
  }

  Future<void> _run(
    GemmaSummaryStyle style, {
    bool forceImmediate = false,
  }) async {
    if (!_entitlement().isActive) {
      if (!mounted) return;
      setState(() {
        _locked = true;
        _running = false;
        _text = null;
      });
      return;
    }
    setState(() {
      _running = true;
      _pendingStyle = style;
      _locked = false;
    });
    try {
      final result = await (widget.service ?? GemmaSummaryService()).summarize(
        transcript: widget.transcript,
        style: style,
        forceImmediate: forceImmediate,
      );
      if (!mounted) return;
      setState(() {
        _deferred = result.deferred;
        _text = result.text;
        _running = false;
      });
      if (!result.deferred && result.text.isNotEmpty) {
        _save(result.text);
      }
    } on Object {
      if (!mounted) return;
      setState(() => _running = false);
    }
  }

  void _save(String text) {
    try {
      ProviderScope.containerOf(
            context,
            listen: false,
          )
          .read(gemmaSummaryProvider.notifier)
          .save(
            entryId: widget.entryId,
            text: text,
          );
    } on Object {
      return;
    }
  }

  void _openPaywall() {
    final container = _maybeContainer();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          final sheet = SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.92,
            child: const PaywallView(),
          );
          if (container != null) {
            return UncontrolledProviderScope(
              container: container,
              child: sheet,
            );
          }
          return ProviderScope(child: sheet);
        },
      ),
    );
  }

  ProviderContainer? _maybeContainer() {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } on Object {
      return null;
    }
  }
}
