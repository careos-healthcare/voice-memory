import 'dart:async';

import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter/material.dart';

/// Language codes handed to on-device speech and to Whisper.
abstract final class TranscriptionLanguage {
  TranscriptionLanguage._();

  static const supported = ['en', 'es', 'fr', 'de', 'hi', 'ja'];

  static String whisperCode(ConfirmedSpeechLocale locale) {
    final code = locale.primaryLanguageSubtag;
    if (supported.contains(code)) return code;
    return 'en';
  }
}

class SpeechLanguagePreferences extends StatefulWidget {
  const SpeechLanguagePreferences({
    required this.readLanguage,
    required this.writeLanguage,
    super.key,
  });

  final Future<String?> Function() readLanguage;
  final Future<void> Function(String identifier) writeLanguage;

  static const preferenceKey = 'speech_language';

  @override
  State<SpeechLanguagePreferences> createState() =>
      _SpeechLanguagePreferencesState();
}

class _SpeechLanguagePreferencesState extends State<SpeechLanguagePreferences> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await widget.readLanguage();
    if (!mounted) return;
    setState(() => _selected = value);
  }

  @override
  Widget build(BuildContext context) {
    return SpeechLanguageSettings(
      selected: _selected,
      onSelected: (value) async {
        await widget.writeLanguage(value);
        if (!mounted) return;
        setState(() => _selected = value);
      },
    );
  }
}

class SpeechLanguageSettings extends StatelessWidget {
  const SpeechLanguageSettings({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final choices = SpeechLocaleCatalog.offered.where((locale) {
      return TranscriptionLanguage.supported.contains(
        locale.locale.primaryLanguageSubtag,
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Speech language', style: Theme.of(context).textTheme.titleMedium),
        for (final locale in choices)
          RadioListTile<String>(
            key: Key('speech_language_${locale.identifier}'),
            contentPadding: EdgeInsets.zero,
            title: Text('${locale.displayName} · ${locale.endonym}'),
            value: locale.identifier,
            groupValue: selected,
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
          ),
      ],
    );
  }
}
