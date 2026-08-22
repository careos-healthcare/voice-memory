import 'dart:async';

import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_language_choice_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Asks, once, which language the customer speaks into the app.
///
/// Folded into the post-save slot next to [LocalTranscriptionUnavailableCard]
/// rather than given a screen of its own: the recording is already saved with
/// its audio by the time this appears, so nothing is blocked on the answer, and
/// the question arrives at the first moment it has visible consequences.
///
/// There is no preselected item and no "use my phone's language" shortcut. The
/// confirm button stays disabled until something is picked, so the card cannot
/// be completed by tapping through it.
class SpeechLanguageChoiceCard extends StatefulWidget {
  const SpeechLanguageChoiceCard({
    required this.onConfirmed,
    super.key,
    this.submitting = false,
    this.offered = SpeechLocaleCatalog.offered,
    this.deviceLocales = NativeSpeechTranscription.supportedLocaleIdentifiers,
  });

  final ValueChanged<ConfirmedSpeechLocale> onConfirmed;
  final bool submitting;

  /// The list to show until the device answers, and the fallback if it never
  /// does.
  final List<OfferedSpeechLocale> offered;

  /// Asks the device which languages its recogniser actually knows.
  ///
  /// The curated [offered] list covers 13 languages; the device reports 63.
  /// Someone who speaks one of the other 50 could not select their language
  /// here at all, which meant the private transcription path was open to 13
  /// languages and everyone else had to choose between privacy and a
  /// transcript.
  ///
  /// Returning an empty list means "no answer", not "no languages", and leaves
  /// [offered] in place.
  final Future<List<String>> Function() deviceLocales;

  @override
  State<SpeechLanguageChoiceCard> createState() =>
      _SpeechLanguageChoiceCardState();
}

class _SpeechLanguageChoiceCardState extends State<SpeechLanguageChoiceCard> {
  OfferedSpeechLocale? _selected;
  late List<OfferedSpeechLocale> _offered = widget.offered;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDeviceLocales());
  }

  /// Widens the list once the device answers.
  ///
  /// Nothing is selected as a result — the customer still picks, and this card
  /// still has no preselected item and no "use my phone's language" shortcut.
  /// A list that arrives after a choice has been made is dropped rather than
  /// swapped in, so the selection cannot be pulled out from under them.
  Future<void> _loadDeviceLocales() async {
    final identifiers = await widget.deviceLocales();
    if (!mounted || identifiers.isEmpty || _selected != null) return;
    final resolved = SpeechLocaleCatalog.offeredForDevice(identifiers);
    if (resolved.length <= _offered.length) return;
    setState(() => _offered = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Container(
      key: const Key('speech_language_choice_card'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              SpeechLanguageChoiceCopy.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _Body(SpeechLanguageChoiceCopy.body),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<OfferedSpeechLocale>(
            key: const Key('speech_language_choice_picker'),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: SpeechLanguageChoiceCopy.pickerLabel,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final entry in _offered)
                DropdownMenuItem<OfferedSpeechLocale>(
                  value: entry,
                  child: Text(_label(entry)),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) => setState(() => _selected = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('speech_language_confirm'),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
            ),
            onPressed: selected == null || widget.submitting
                ? null
                : () => widget.onConfirmed(selected.locale),
            child: const Text(SpeechLanguageChoiceCopy.confirmCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _Body(SpeechLanguageChoiceCopy.missingLanguageNote),
          const SizedBox(height: AppSpacing.sm),
          const _Body(SpeechLanguageChoiceCopy.footnote),
        ],
      ),
    );
  }

  static String _label(OfferedSpeechLocale entry) =>
      entry.endonym == entry.displayName
          ? entry.displayName
          : '${entry.endonym} — ${entry.displayName}';
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}
