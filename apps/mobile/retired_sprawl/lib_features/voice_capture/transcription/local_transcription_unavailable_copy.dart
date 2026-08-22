/// Copy for the one-time prompt shown when this device cannot transcribe.
///
/// Names the processor that would receive the audio, because "send it to the
/// server" hides the part a customer would want to know. Verified against
/// `apps/api/app/api/transcribe/route.ts`, which posts the audio file to
/// OpenAI's transcription endpoint with the `whisper-1` model. Nothing in that
/// route or its callers involves any other transcription provider.
abstract final class LocalTranscriptionUnavailableCopy {
  LocalTranscriptionUnavailableCopy._();

  static const String title = 'This device cannot write out what you said';

  static const String body =
      'Transcription on the device itself is not working here, so a recording '
      'saved now keeps its audio and has no text with it. Text is what search '
      'and reflection read, so this is worth a decision rather than a shrug.';

  static const String remoteCta = 'Send audio for transcription';

  static const String remoteDetail =
      'The audio file goes to our server, which passes it to OpenAI for '
      'transcription using the whisper-1 model, and the text comes back to '
      'this device. Reflection is a separate permission you can review in '
      'Settings → Privacy.';

  static const String declineCta = 'Save without text';

  static const String declineDetail =
      'The recording is kept on this device with its audio. Features that '
      'need text do not have any for that moment. You can change this later '
      'in Settings → Privacy.';

  static const String footnote =
      'We ask this once. Whichever you pick, we keep it until you change it in '
      'Settings → Privacy.';
}
