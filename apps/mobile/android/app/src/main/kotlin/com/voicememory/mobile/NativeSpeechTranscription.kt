package com.voicememory.mobile

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.io.File

object NativeSpeechTranscription {
    fun transcribe(
        context: android.content.Context,
        audioPath: String,
        preferOnDevice: Boolean,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        val audioFile = File(audioPath)
        if (!audioFile.exists()) {
            callback(mapOf("transcript" to "", "reason" to "audio_missing"))
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            callback(mapOf("transcript" to "", "reason" to "recognizer_unavailable"))
            return
        }

        val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            if (preferOnDevice) {
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
        }

        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                recognizer.destroy()
                callback(mapOf("transcript" to "", "reason" to "android_stt_error_$error"))
            }

            override fun onResults(results: Bundle?) {
                val matches = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                    ?.trim()
                    .orEmpty()
                recognizer.destroy()
                callback(
                    mapOf(
                        "transcript" to matches,
                        "reason" to if (matches.isEmpty()) "empty_native_transcript" else "",
                    ),
                )
            }

            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val player = android.media.MediaPlayer()
        try {
            player.setDataSource(audioPath)
            player.prepare()
            player.start()
            recognizer.startListening(intent)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (player.isPlaying) {
                    player.stop()
                }
                player.release()
            }, (player.duration + 500).coerceAtLeast(1500).toLong())
        } catch (error: Exception) {
            player.release()
            recognizer.destroy()
            callback(mapOf("transcript" to "", "reason" to error.message))
        }
    }
}

object NativeSpeechTranscriptionHandler {
    fun handle(
        context: android.content.Context,
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result,
    ) {
        when (call.method) {
            "transcribeFile" -> {
                val args = call.arguments as? Map<*, *>
                val audioPath = args?.get("audioPath") as? String
                if (audioPath.isNullOrBlank()) {
                    result.error("invalid_args", "Expected audioPath", null)
                    return
                }
                val preferOnDevice = args["preferOnDevice"] as? Boolean ?: true
                NativeSpeechTranscription.transcribe(
                    context = context,
                    audioPath = audioPath,
                    preferOnDevice = preferOnDevice,
                ) { payload ->
                    result.success(payload)
                }
            }
            else -> result.notImplemented()
        }
    }
}
