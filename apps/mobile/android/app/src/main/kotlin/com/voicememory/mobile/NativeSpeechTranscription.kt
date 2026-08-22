package com.voicememory.mobile

/**
 * Android native speech-to-text is disabled. Do not re-enable this without
 * reading the whole comment.
 *
 * This file used to transcribe a saved recording by playing it back through the
 * device speaker while the microphone recognizer listened. That is an acoustic
 * loopback, and it is unacceptable for this app for two independent reasons:
 *
 *  1. Dignity. It plays a private mental-health reflection out loud, in
 *     whatever room the phone happens to be in.
 *  2. Privacy. The "prefer offline" recognizer flag is only a hint. On a device
 *     with no offline recognizer installed, the platform recognizer streams the
 *     microphone audio to Google's servers — an upload the customer never
 *     consented to and the product copy says never happens.
 *
 * The correct API for this job is the on-device recognizer factory added in
 * API 31, which takes an audio source directly and needs no playback. If you
 * implement it, keep it strictly on-device, gate it behind the same
 * `RemoteProcessingConsentGate` predicate the rest of the app uses, and flip
 * `NativeSpeechTranscription.blockedPlatforms` in
 * `lib/features/voice_capture/transcription/native_speech_transcription.dart`
 * in the same change — the Dart side refuses to call this channel on Android,
 * so restoring a Kotlin implementation alone does nothing.
 *
 * `test/features/voice_capture/native_speech_android_disabled_test.dart` scans
 * this file and fails if the loopback APIs reappear.
 */
object NativeSpeechTranscriptionHandler {
    private const val DISABLED_CODE = "android_native_stt_disabled"
    private const val DISABLED_MESSAGE =
        "Android native speech-to-text is disabled: the only implementation " +
            "available here required playing the recording out loud for the " +
            "microphone recognizer, which exposes private audio to the room " +
            "and to Google."

    fun handle(
        context: android.content.Context,
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result,
    ) {
        when (call.method) {
            "transcribeFile" -> result.error(DISABLED_CODE, DISABLED_MESSAGE, null)
            else -> result.notImplemented()
        }
    }
}
