import 'package:flutter/material.dart';

import '../../features/ai_engines/models/ai_accuracy_feedback.dart';

typedef AiAccuracyFeedbackSubmit =
    Future<AiAccuracyFeedback> Function(
      AiFeedbackState state,
      String? correctionNote,
    );

class AiAccuracyBar extends StatefulWidget {
  const AiAccuracyBar({
    super.key,
    required this.initialFeedback,
    required this.onSubmit,
    this.loadFeedback,
    this.showConfidence = true,
  });

  final AiAccuracyFeedback initialFeedback;
  final AiAccuracyFeedbackSubmit onSubmit;
  final Future<AiAccuracyFeedback?> Function()? loadFeedback;
  final bool showConfidence;

  @override
  State<AiAccuracyBar> createState() => _AiAccuracyBarState();
}

class _AiAccuracyBarState extends State<AiAccuracyBar> {
  late AiAccuracyFeedback _feedback = widget.initialFeedback;
  var _busy = false;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final restored = await widget.loadFeedback?.call();
    if (restored != null && mounted) setState(() => _feedback = restored);
  }

  Future<void> _submit(AiFeedbackState state, {String? correctionNote}) async {
    if (_busy) return;
    final learns =
        state == AiFeedbackState.correct || state == AiFeedbackState.incorrect;
    if (learns) setState(() => _busy = true);
    try {
      final saved = await widget.onSubmit(state, correctionNote);
      if (!mounted) return;
      setState(() {
        _feedback = saved;
        _saved = learns;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markIncorrect() async {
    var correction = '';
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What did we get wrong?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ai_accuracy_correction_note'),
                autofocus: true,
                onChanged: (value) => correction = value,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Optional correction',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('ai_accuracy_correction_skip'),
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('ai_accuracy_correction_submit'),
                    onPressed: () => Navigator.pop(context, correction.trim()),
                    child: const Text('Save feedback'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (note == null) return;
    await _submit(AiFeedbackState.incorrect, correctionNote: note);
  }

  @override
  Widget build(BuildContext context) {
    final deferred = _feedback.isDeferredAt(DateTime.now().toUtc());
    final completed =
        _feedback.feedbackState == AiFeedbackState.correct ||
        _feedback.feedbackState == AiFeedbackState.incorrect;
    if (deferred) {
      return const SizedBox.shrink(key: Key('ai_accuracy_deferred'));
    }
    return Semantics(
      container: true,
      label:
          '${_feedback.confidencePercentage}% AI confidence. Accuracy feedback.',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        child: _busy
            ? const Row(
                key: Key('ai_accuracy_learning'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Learning...'),
                ],
              )
            : (_saved || completed)
            ? const Row(
                key: Key('ai_accuracy_saved_confirmation'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green),
                  SizedBox(width: 8),
                  Flexible(child: Text('Feedback integrated. Graph updated.')),
                ],
              )
            : Wrap(
                key: const Key('ai_accuracy_pending'),
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.showConfidence)
                    Chip(
                      key: const Key('ai_accuracy_confidence_pill'),
                      avatar: const Icon(Icons.verified_outlined, size: 18),
                      label: Text(
                        '${_feedback.confidencePercentage}% Confidence',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    key: const Key('ai_accuracy_correct'),
                    onPressed: _busy
                        ? null
                        : () => _submit(AiFeedbackState.correct),
                    icon: const Icon(Icons.thumb_up_outlined),
                    label: const Text('Correct'),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('ai_accuracy_incorrect'),
                    onPressed: _busy ? null : _markIncorrect,
                    icon: const Icon(Icons.thumb_down_outlined),
                    label: const Text('Incorrect'),
                  ),
                  TextButton.icon(
                    key: const Key('ai_accuracy_later'),
                    onPressed: _busy
                        ? null
                        : () => _submit(AiFeedbackState.later),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Later'),
                  ),
                ],
              ),
      ),
    );
  }
}
