package com.voicememory.mobile

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.k2fsa.sherpa.onnx.OnlineModelConfig
import com.k2fsa.sherpa.onnx.OnlineRecognizer
import com.k2fsa.sherpa.onnx.OnlineRecognizerConfig
import com.k2fsa.sherpa.onnx.OnlineStream
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Live draft only. Saved-file transcription stays refused: playing a recording
 * out loud so a microphone recogniser can hear it is not allowed.
 *
 * Streaming uses the bundled Sherpa transducer in `assets/sherpa_streaming/`
 * (encoder.onnx, decoder.onnx, joiner.onnx, tokens.txt), copied into the cache
 * on first run. If that model cannot start, API 31+ uses the on-device
 * platform recogniser. Neither path uploads audio.
 */
object NativeSpeechTranscriptionHandler : EventChannel.StreamHandler {
    private const val DISABLED_CODE = "android_native_stt_disabled"
    private const val DISABLED_MESSAGE =
        "Android file transcription is disabled. Live draft uses the on-device model."
    private const val ASSET_DIR = "sherpa_streaming"
    private val modelFiles = listOf(
        "encoder.onnx",
        "decoder.onnx",
        "joiner.onnx",
        "tokens.txt",
    )

    private val main = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private val paused = AtomicBoolean(false)

    @Volatile
    private var sink: EventChannel.EventSink? = null

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var recognizer: OnlineRecognizer? = null
    private var stream: OnlineStream? = null
    private var platformRecognizer: SpeechRecognizer? = null

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "transcribeFile" -> {
                result.error(DISABLED_CODE, DISABLED_MESSAGE, null)
            }
            "startLiveDraft" -> startLiveDraft(
                context.applicationContext,
                call.argument<String>("localeIdentifier"),
                call.argument<Boolean>("preferSherpa") ?: true,
                call.argument<String>("modelDir"),
                result,
            )
            "feedLiveDraftPcm" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes != null) feedPcm(bytes)
                result.success(null)
            }
            "pauseLiveDraft" -> {
                paused.set(true)
                platformRecognizer?.stopListening()
                result.success(null)
            }
            "resumeLiveDraft" -> {
                paused.set(false)
                restartPlatform()
                result.success(null)
            }
            "probeLiveDraft" -> result.success(
                mapOf(
                    "sherpa" to (prepareModels(context.applicationContext) != null),
                    "platform" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
                ),
            )
            "stopLiveDraft" -> {
                stopLiveDraft()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        stopLiveDraft()
    }

    private var platformIntent: Intent? = null

    private fun startLiveDraft(
        context: Context,
        locale: String?,
        preferSherpa: Boolean,
        modelDir: String?,
        result: MethodChannel.Result,
    ) {
        stopLiveDraft()
        paused.set(false)
        Thread {
            val sherpa = preferSherpa && tryStartSherpa(context, modelDir)
            main.post {
                val started = sherpa || tryStartPlatform(context, locale)
                if (started) {
                    result.success(null)
                } else {
                    result.error(
                        "live_draft_failed",
                        "No on-device streaming recogniser is available.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun tryStartSherpa(context: Context, modelDir: String?): Boolean {
        return try {
            val dir = modelDirectory(context, modelDir) ?: return false
            val config = OnlineRecognizerConfig(
                modelConfig = OnlineModelConfig(
                    transducer = OnlineTransducerModelConfig(
                        encoder = File(dir, "encoder.onnx").absolutePath,
                        decoder = File(dir, "decoder.onnx").absolutePath,
                        joiner = File(dir, "joiner.onnx").absolutePath,
                    ),
                    tokens = File(dir, "tokens.txt").absolutePath,
                    numThreads = 2,
                    provider = "cpu",
                    modelType = "zipformer2",
                ),
                enableEndpoint = true,
                decodingMethod = "greedy_search",
            )
            val online = OnlineRecognizer(assetManager = null, config = config)
            val onlineStream = online.createStream()
            recognizer = online
            stream = onlineStream
            running.set(true)
            true
        } catch (_: Throwable) {
            stopLiveDraft()
            false
        }
    }

    private fun modelDirectory(context: Context, modelDir: String?): File? {
        val requested = modelDir?.let(::File)
        if (requested != null && modelFiles.all { name ->
                File(requested, name).isFile && File(requested, name).length() > 0L
            }
        ) {
            return requested
        }
        val downloaded = File(context.filesDir, "streaming_zipformer_en")
        if (modelFiles.all { name ->
                File(downloaded, name).isFile && File(downloaded, name).length() > 0L
            }
        ) {
            return downloaded
        }
        return prepareModels(context)
    }

    private fun prepareModels(context: Context): File? {
        val dest = File(context.cacheDir, ASSET_DIR)
        if (!dest.exists() && !dest.mkdirs()) return null
        for (name in modelFiles) {
            val out = File(dest, name)
            if (out.isFile && out.length() > 0L) continue
            if (!copyAsset(context, name, out)) return null
        }
        return dest
    }

    private fun copyAsset(context: Context, name: String, out: File): Boolean {
        val candidates = listOf(
            "$ASSET_DIR/$name",
            "flutter_assets/assets/models/$ASSET_DIR/$name",
        )
        for (path in candidates) {
            try {
                context.assets.open(path).use { input ->
                    out.outputStream().use { output -> input.copyTo(output) }
                }
                if (out.isFile && out.length() > 0L) return true
            } catch (_: Throwable) {
                out.delete()
            }
        }
        return false
    }

    private fun feedPcm(bytes: ByteArray) {
        if (paused.get() || !running.get() || bytes.size < 2) return
        val online = recognizer ?: return
        val onlineStream = stream ?: return
        val samples = FloatArray(bytes.size / 2)
        var index = 0
        while (index < samples.size) {
            val lo = bytes[index * 2].toInt() and 0xff
            val hi = bytes[index * 2 + 1].toInt() and 0xff
            var value = lo or (hi shl 8)
            if (value >= 0x8000) value -= 0x10000
            samples[index] = value / 32768.0f
            index += 1
        }
        try {
            onlineStream.acceptWaveform(samples, 16000)
            while (online.isReady(onlineStream)) {
                online.decode(onlineStream)
            }
            val text = online.getResult(onlineStream).text.trim()
            if (text.isNotEmpty()) emit(text)
        } catch (_: Throwable) {
            // A bad chunk does not open another microphone.
        }
    }

    private fun tryStartPlatform(context: Context, locale: String?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return try {
            val speech = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            platformRecognizer = speech
            running.set(true)
            speech.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onError(error: Int) = Unit
                override fun onPartialResults(partialResults: Bundle?) {
                    emitBundle(partialResults)
                }
                override fun onResults(results: Bundle?) {
                    emitBundle(results)
                }
                override fun onEvent(eventType: Int, params: Bundle?) = Unit
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                val language = locale?.trim().orEmpty()
                if (language.isNotEmpty()) {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                }
            }
            platformIntent = intent
            val manager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            manager.mode = android.media.AudioManager.MODE_IN_COMMUNICATION
            speech.startListening(intent)
            true
        } catch (_: Throwable) {
            platformRecognizer?.destroy()
            platformRecognizer = null
            false
        }
    }

    private fun emitBundle(bundle: Bundle?) {
        val text = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()
        if (text.isNotEmpty()) emit(text)
    }

    private fun emit(text: String) {
        val events = sink ?: return
        main.post {
            try {
                events.success(text)
            } catch (_: Throwable) {
                // The draft listener has already gone away.
            }
        }
    }

    private fun stopLiveDraft() {
        running.set(false)
        audioRecord?.run {
            try {
                stop()
            } catch (_: Throwable) {
                // Already stopped.
            }
            release()
        }
        audioRecord = null
        captureThread?.join(500)
        captureThread = null
        releaseSherpa()
        platformRecognizer?.run {
            try {
                stopListening()
            } catch (_: Throwable) {
                // Already stopped.
            }
            destroy()
        }
        platformRecognizer = null
        platformIntent = null
    }

    private fun restartPlatform() {
        val speech = platformRecognizer ?: return
        val intent = platformIntent ?: return
        if (paused.get()) return
        try {
            speech.startListening(intent)
        } catch (_: Throwable) {
            // The on-device recogniser has already stopped.
        }
    }

    private fun releaseSherpa() {
        try {
            stream?.release()
        } catch (_: Throwable) {
            // Already released.
        }
        stream = null
        try {
            recognizer?.release()
        } catch (_: Throwable) {
            // Already released.
        }
        recognizer = null
    }
}
