import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_availability.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_choice_store.dart';

/// What the capture flow should do about transcription for this recording.
enum TranscriptionCapabilityOutcome {
  /// Something can produce a transcript. Say nothing.
  proceed,

  /// Local transcription cannot run and remote is not permitted. Ask, once.
  askOnce,

  /// The device can transcribe locally but has not been told which language to
  /// listen for. Ask which, once.
  ///
  /// A different question from [askOnce], and not answerable by the same
  /// stored choice: "send it to a server" and "I speak Gujarati" are not two
  /// answers to one thing. Kept separate so that picking a language is never
  /// presented as a privacy decision, and so that declining to upload does not
  /// get recorded as declining to be transcribed at all.
  askSpeechLanguage,

  /// The customer already chose to save without a transcript. Say nothing.
  respectNoTranscription,
}

/// Decides whether the customer has to be asked about a transcription gap.
///
/// Pure, and deliberately blind to the network. Its inputs are a device
/// capability, a permission, and a stored answer; none of them can be a request
/// failure. That is the whole separation between a capability gap and a flaky
/// connection: a timeout, a 500, or an offline error changes no input here, so
/// it cannot raise a privacy prompt. A recording that fails to upload is a
/// retry, which `ProvisionalTranscriptReconciler` and the pipeline's sync notes
/// already handle.
abstract final class TranscriptionCapabilityPolicy {
  TranscriptionCapabilityPolicy._();

  static TranscriptionCapabilityOutcome decide({
    required LocalTranscriptionSupport localSupport,
    required bool remoteTranscriptionPermitted,
    required LocalTranscriptionChoice recordedChoice,
  }) {
    if (localSupport.isAvailable) return TranscriptionCapabilityOutcome.proceed;

    // Remote permitted means the server already produces text, so nothing is
    // missing and there is no question to ask — including the language one,
    // which can wait until the customer turns on-device-only on.
    if (remoteTranscriptionPermitted) {
      return TranscriptionCapabilityOutcome.proceed;
    }

    // "Save without text" is a standing answer to the whole subject. Someone
    // who gave it is not asked again, including about language: the alternative
    // is turning one honoured decision into a second prompt with a new heading.
    if (recordedChoice == LocalTranscriptionChoice.noTranscription) {
      return TranscriptionCapabilityOutcome.respectNoTranscription;
    }

    if (localSupport.reason ==
        LocalTranscriptionUnavailableReason.speechLanguageUnconfirmed) {
      return TranscriptionCapabilityOutcome.askSpeechLanguage;
    }

    // A recorded `remoteTranscription` answer with remote still not permitted
    // means the grant did not take or was withdrawn afterwards. Asking again is
    // right: the alternative is a customer who said "transcribe it" getting
    // silence forever.
    return TranscriptionCapabilityOutcome.askOnce;
  }
}
