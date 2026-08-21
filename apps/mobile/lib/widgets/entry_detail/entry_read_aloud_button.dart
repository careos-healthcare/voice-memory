import 'dart:async';

import 'package:archiveme_mobile/features/entry_detail/entry_read_aloud_copy.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';
import 'package:flutter/material.dart';

/// Offline read-aloud control — streams entry/reflection text through TTS.
class EntryReadAloudButton extends StatefulWidget {
  const EntryReadAloudButton({
    required this.text,
    this.offlineTts,
    this.resolveOfflineTts,
    super.key,
  });

  final String text;
  final OfflineTtsService? offlineTts;

  /// When null and [offlineTts] is null, the control stays hidden.
  final Future<OfflineTtsService?> Function()? resolveOfflineTts;

  @override
  State<EntryReadAloudButton> createState() => _EntryReadAloudButtonState();
}

class _EntryReadAloudButtonState extends State<EntryReadAloudButton> {
  OfflineTtsService? _service;
  var _resolving = false;
  var _speaking = false;
  var _preparing = false;

  @override
  void initState() {
    super.initState();
    _service = widget.offlineTts;
    if (_service == null && widget.resolveOfflineTts != null) {
      unawaited(_resolveService());
    }
  }

  @override
  void didUpdateWidget(covariant EntryReadAloudButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offlineTts != oldWidget.offlineTts) {
      _service = widget.offlineTts;
    }
    if (oldWidget.text != widget.text && _speaking) {
      unawaited(_stopSpeaking());
    }
  }

  @override
  void dispose() {
    unawaited(_stopSpeaking(updateState: false));
    super.dispose();
  }

  Future<void> _resolveService() async {
    final resolver = widget.resolveOfflineTts;
    if (_resolving || _service != null || resolver == null) {
      return;
    }
    setState(() => _resolving = true);
    try {
      final service = await resolver();
      if (mounted) {
        setState(() => _service = service);
      }
    } finally {
      if (mounted) {
        setState(() => _resolving = false);
      }
    }
  }

  Future<void> _toggle() async {
    if (_speaking) {
      await _stopSpeaking();
      return;
    }

    var service = _service ?? widget.offlineTts;
    if (service == null && widget.resolveOfflineTts != null) {
      await _resolveService();
      service = _service ?? widget.offlineTts;
    }
    if (service == null || !mounted) {
      return;
    }

    setState(() {
      _preparing = true;
      _speaking = true;
    });

    try {
      await service.speak(widget.text);
    } catch (_, stackTrace) {
      // Surface failures quietly — voice model may be absent on some builds.
    } finally {
      if (mounted) {
        setState(() {
          _preparing = false;
          _speaking = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking({bool updateState = true}) async {
    final service = _service ?? widget.offlineTts;
    if (service != null) {
      await service.stop();
    }
    if (updateState && mounted) {
      setState(() {
        _preparing = false;
        _speaking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    final service = _service ?? widget.offlineTts;
    if (service == null && widget.resolveOfflineTts == null) {
      return const SizedBox.shrink();
    }
    if (service == null && !_resolving) {
      return const SizedBox.shrink();
    }

    final label = _speaking
        ? (_preparing ? EntryReadAloudCopy.loading : EntryReadAloudCopy.stop)
        : EntryReadAloudCopy.listen;
    final icon = _speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('entry_read_aloud_button'),
        onPressed: (service == null && _resolving) || _preparing ? null : _toggle,
        icon: _preparing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}