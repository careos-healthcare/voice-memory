import 'package:flutter/material.dart';

import 'remote_transcription_disclosure.dart';

enum RemoteTranscriptionDisclosureAction { continueOnline, notNow, typeInstead }

abstract final class RemoteTranscriptionDisclosureCopy {
  static const title = 'Online transcription';
  static const body =
      'To turn this recording into text, ArchiveMe will upload the audio '
      'to our server and send it to OpenAI for transcription. The audio '
      'leaves this device. Continue only if you are comfortable with that.';
  static const learnMore =
      'Your recording is used to produce a transcript. You can withdraw '
      'permission for future recordings at any time in Privacy settings.';
  static const continueOnline = 'Continue with online transcription';
  static const notNow = 'Not now';
  static const typeInstead = 'Type instead';
  static const learnMoreAction = 'Learn more';

  static const interpretationTitle = 'Online interpretation';
  static const interpretationBody =
      'To produce a possible read, ArchiveMe will upload the text of this '
      'already-saved moment to our server and send it to OpenAI. The text '
      'leaves this device. This is separate from transcription permission. '
      'Declining does not block your Archive, and you can ask again later.';
  static const interpretationLearnMore =
      'The text is used to produce one suggested interpretation, which never '
      'replaces what you said. You can withdraw permission at any time in '
      'settings, and delete the result afterwards.';
  static const continueInterpretation = 'Continue with online interpretation';

  static String titleFor(RemoteProcessingPurpose purpose) => switch (purpose) {
    RemoteProcessingPurpose.transcription => title,
    RemoteProcessingPurpose.interpretation => interpretationTitle,
  };

  static String bodyFor(RemoteProcessingPurpose purpose) => switch (purpose) {
    RemoteProcessingPurpose.transcription => body,
    RemoteProcessingPurpose.interpretation => interpretationBody,
  };

  static String learnMoreFor(RemoteProcessingPurpose purpose) =>
      switch (purpose) {
        RemoteProcessingPurpose.transcription => learnMore,
        RemoteProcessingPurpose.interpretation => interpretationLearnMore,
      };

  static String continueCtaFor(RemoteProcessingPurpose purpose) =>
      switch (purpose) {
        RemoteProcessingPurpose.transcription => continueOnline,
        RemoteProcessingPurpose.interpretation => continueInterpretation,
      };
}

Future<RemoteTranscriptionDisclosureAction?> showRemoteTranscriptionDisclosure({
  required BuildContext context,
  required RemoteTranscriptionDisclosureStore store,
  RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
}) {
  return showDialog<RemoteTranscriptionDisclosureAction>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _RemoteTranscriptionDisclosureDialog(store: store, purpose: purpose),
  );
}

final class _RemoteTranscriptionDisclosureDialog extends StatefulWidget {
  const _RemoteTranscriptionDisclosureDialog({
    required this.store,
    required this.purpose,
  });

  final RemoteTranscriptionDisclosureStore store;
  final RemoteProcessingPurpose purpose;

  @override
  State<_RemoteTranscriptionDisclosureDialog> createState() =>
      _RemoteTranscriptionDisclosureDialogState();
}

final class _RemoteTranscriptionDisclosureDialogState
    extends State<_RemoteTranscriptionDisclosureDialog> {
  bool _showLearnMore = false;
  bool _accepting = false;

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await widget.store.acceptCurrent(purpose: widget.purpose);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(RemoteTranscriptionDisclosureAction.continueOnline);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      child: AlertDialog(
        key: const Key('remote_transcription_disclosure_dialog'),
        title: Text(RemoteTranscriptionDisclosureCopy.titleFor(widget.purpose)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(RemoteTranscriptionDisclosureCopy.bodyFor(widget.purpose)),
              if (_showLearnMore) ...[
                const SizedBox(height: 16),
                Text(
                  RemoteTranscriptionDisclosureCopy.learnMoreFor(
                    widget.purpose,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('remote_disclosure_learn_more'),
            onPressed: _accepting
                ? null
                : () => setState(() => _showLearnMore = true),
            child: const Text(
              RemoteTranscriptionDisclosureCopy.learnMoreAction,
            ),
          ),
          if (widget.purpose == RemoteProcessingPurpose.transcription)
            TextButton(
              key: const Key('remote_disclosure_type_instead'),
              onPressed: _accepting
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(RemoteTranscriptionDisclosureAction.typeInstead),
              child: const Text(RemoteTranscriptionDisclosureCopy.typeInstead),
            ),
          TextButton(
            key: const Key('remote_disclosure_not_now'),
            onPressed: _accepting
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(RemoteTranscriptionDisclosureAction.notNow),
            child: const Text(RemoteTranscriptionDisclosureCopy.notNow),
          ),
          FilledButton(
            key: const Key('remote_disclosure_continue'),
            onPressed: _accepting ? null : _accept,
            child: _accepting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    RemoteTranscriptionDisclosureCopy.continueCtaFor(
                      widget.purpose,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
