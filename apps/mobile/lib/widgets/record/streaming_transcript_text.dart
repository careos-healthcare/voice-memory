import 'dart:async';

import 'package:flutter/material.dart';

/// Appends a live transcript inside a fixed viewport.
///
/// New text eases to the end of the line. A burst of chunks shares one
/// scroll, and a manual scroll away from the end stays put.
class StreamingTranscriptText extends StatefulWidget {
  const StreamingTranscriptText({
    super.key,
    this.text = '',
    this.chunks,
    this.height = 112,
  });

  final String text;
  final Stream<String>? chunks;
  final double height;

  static const emptyLabel = 'Words show up here as they arrive.';

  @override
  State<StreamingTranscriptText> createState() =>
      _StreamingTranscriptTextState();
}

class _StreamingTranscriptTextState extends State<StreamingTranscriptText> {
  final _scroll = ScrollController();
  StreamSubscription<String>? _chunks;
  var _text = '';
  var _pinned = true;
  var _following = false;
  var _followAgain = false;

  @override
  void initState() {
    super.initState();
    _text = widget.text;
    _scroll.addListener(_onScroll);
    _listen(widget.chunks);
  }

  @override
  void didUpdateWidget(covariant StreamingTranscriptText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chunks != widget.chunks) {
      _listen(widget.chunks);
    }
    if (widget.chunks == null && widget.text != _text) {
      setState(() => _text = widget.text);
      _scheduleFollow();
    }
  }

  @override
  void dispose() {
    final pending = _chunks?.cancel();
    if (pending != null) unawaited(pending);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _listen(Stream<String>? chunks) {
    final pending = _chunks?.cancel();
    if (pending != null) unawaited(pending);
    _chunks = chunks?.listen((value) {
      if (!mounted || value == _text) return;
      setState(() => _text = value);
      _scheduleFollow();
    });
  }

  void _onScroll() {
    if (_following || !_scroll.hasClients) return;
    final position = _scroll.position;
    _pinned = position.maxScrollExtent - position.pixels <= 48;
  }

  void _scheduleFollow() {
    if (!_pinned) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_follow());
    });
  }

  Future<void> _follow() async {
    if (!mounted || !_pinned || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= _scroll.offset + 1) return;
    if (_following) {
      _followAgain = true;
      return;
    }
    _following = true;
    await _scroll.animateTo(
      max,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    _following = false;
    if (_followAgain) {
      _followAgain = false;
      _scheduleFollow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final showing = _text.trim().isEmpty
        ? StreamingTranscriptText.emptyLabel
        : _text;
    final quiet = _text.trim().isEmpty;
    return SizedBox(
      height: widget.height,
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          child: Text(
            showing,
            key: const Key('recording_transcription_view'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: ink.withValues(alpha: quiet ? 0.42 : 1),
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}
