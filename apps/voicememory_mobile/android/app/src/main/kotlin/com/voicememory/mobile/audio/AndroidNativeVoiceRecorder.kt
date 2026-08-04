package com.voicememory.mobile.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AudioEffect
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

internal enum class ProcessingControl(val channelValue: String) {
    PLATFORM_DEFAULT("default"),
    ENABLED("enabled"),
    DISABLED("disabled");

    companion object {
        fun from(value: Any?): ProcessingControl = when (value?.toString()) {
            "enabled" -> ENABLED
            "disabled" -> DISABLED
            else -> PLATFORM_DEFAULT
        }
    }
}

internal data class ProcessingRequest(
    val acousticEchoCancellation: ProcessingControl,
    val noiseSuppression: ProcessingControl,
    val automaticGainControl: ProcessingControl,
) {
    fun payload(): Map<String, String> = mapOf(
        "acousticEchoCancellation" to acousticEchoCancellation.channelValue,
        "noiseSuppression" to noiseSuppression.channelValue,
        "automaticGainControl" to automaticGainControl.channelValue,
    )
}

private data class ProcessingEffect(
    val effect: AudioEffect?,
    val supported: Boolean,
    val enabled: Boolean?,
)

private data class ProcessingEffects(
    val requested: ProcessingRequest,
    val applied: ProcessingRequest,
    val acousticEchoCancellation: ProcessingEffect,
    val noiseSuppression: ProcessingEffect,
    val automaticGainControl: ProcessingEffect,
) {
    private val releaseOnce = OnceAction {
        runCatching { acousticEchoCancellation.effect?.release() }
        runCatching { noiseSuppression.effect?.release() }
        runCatching { automaticGainControl.effect?.release() }
    }

    fun release() = releaseOnce.run()

    fun payload(): Map<String, Any> = mapOf(
        "requested" to requested.payload(),
        "applied" to applied.payload(),
        "supported" to mapOf(
            "acousticEchoCancellation" to acousticEchoCancellation.supported,
            "noiseSuppression" to noiseSuppression.supported,
            "automaticGainControl" to automaticGainControl.supported,
        ),
        "enabled" to mapOf(
            "acousticEchoCancellation" to acousticEchoCancellation.enabled,
            "noiseSuppression" to noiseSuppression.enabled,
            "automaticGainControl" to automaticGainControl.enabled,
        ),
        "voiceProcessingMode" to false,
        "platformManaged" to false,
    )
}

class AndroidNativeVoiceRecorder(private val context: Context) {
    private data class CaptureConfig(
        val sampleRate: Int,
        val channels: Int,
        val bitDepth: Int,
        val bufferDurationMs: Double,
        val sessionMode: String,
        val processingRequest: ProcessingRequest,
    ) {
        companion object {
            fun from(arguments: Map<*, *>?): CaptureConfig {
                val config = arguments?.get("config") as? Map<*, *> ?: emptyMap<Any, Any>()
                return CaptureConfig(
                    sampleRate =
                        (config["sampleRate"] as? Number)?.toInt()?.coerceIn(8000, 192000) ?: 16000,
                    channels = 1,
                    bitDepth = 16,
                    bufferDurationMs =
                        (config["bufferDurationMs"] as? Number)
                            ?.toDouble()
                            ?.takeIf { it.isFinite() }
                            ?.coerceIn(1.0, 500.0)
                            ?: 20.0,
                    sessionMode = when (config["sessionMode"]?.toString()) {
                        "measurement", "raw" -> config["sessionMode"].toString()
                        else -> "spokenAudio"
                    },
                    processingRequest = ProcessingRequest(
                        acousticEchoCancellation =
                            ProcessingControl.from(config["acousticEchoCancellation"]),
                        noiseSuppression = ProcessingControl.from(config["noiseSuppression"]),
                        automaticGainControl = ProcessingControl.from(config["automaticGainControl"]),
                    ),
                )
            }
        }
    }

    private data class ActiveCapture(
        val file: File,
        val config: CaptureConfig,
        val sampleRate: Int,
        val bufferBytes: Int,
        val source: Int,
        val record: AudioRecord,
        val audioSessionId: Int,
        val output: RandomAccessFile,
        val startedAtMs: Long,
        val previousAudioMode: Int,
        val focusRequest: AudioFocusRequest?,
        val focusAcquired: Boolean,
        val processingEffects: ProcessingEffects,
        var recordReleased: Boolean = false,
        var outputClosed: Boolean = false,
        var audioSessionRestored: Boolean = false,
        val running: AtomicBoolean = AtomicBoolean(false),
        @Volatile var workerFailure: Throwable? = null,
    )

    private data class AudioFocusState(
        val request: AudioFocusRequest?,
        val acquired: Boolean,
    )

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var active: ActiveCapture? = null
    private var worker: Thread? = null
    private var lastResult: Map<String, Any>? = null
    private var minDb = -160.0
    private var maxDb = -160.0
    private var sumDb = 0.0
    private var sampleCount = 0
    private var latestDb = -160.0

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNativeRecorderAvailable" -> result.success(true)
            "nativeMicrophonePermission", "requestNativeMicrophonePermission" ->
                result.success(permissionPayload())
            "startNativeRecording" -> start(call.arguments as? Map<*, *>, result)
            "stopNativeRecording" -> {
                try {
                    result.success(stop())
                } catch (error: Exception) {
                    result.error(
                        "native_recorder_stop",
                        error.message,
                        mapOf("step" to "stop", "reason" to error.toString()),
                    )
                }
            }
            "currentNativeLevel" -> result.success(levelPayload())
            "disposeNativeRecorder" -> {
                dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onBackground() {
        if (active != null) {
            runCatching { stop() }
        }
    }

    fun dispose() {
        if (active != null) {
            runCatching { stop() }
        }
    }

    fun permissionPayload(canRequest: Boolean = true): Map<String, Any> {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        return mapOf(
            "status" to if (granted) "granted" else "denied",
            "granted" to granted,
            "canRequest" to (!granted && canRequest),
        )
    }

    private fun start(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (permissionPayload()["granted"] != true) {
            result.error(
                "native_recorder_start",
                "Microphone permission is denied",
                mapOf("step" to "microphone_permission_denied"),
            )
            return
        }
        dispose()
        val path = arguments?.get("path")?.toString().orEmpty()
        if (path.isBlank()) {
            result.error(
                "native_recorder_start",
                "Recording path is required",
                mapOf("step" to "create_file_url_failed"),
            )
            return
        }

        val config = CaptureConfig.from(arguments)
        var selectedRecord: AudioRecord? = null
        var output: RandomAccessFile? = null
        val previousMode = audioManager.mode
        var modeChanged = false
        var focusState: AudioFocusState? = null
        var processingEffects: ProcessingEffects? = null
        try {
            val supportsUnprocessed = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                audioManager.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"
            val selection = NativeAudioHelpers.selectAudioRecord(
                config.sampleRate,
                config.bufferDurationMs,
                config.sessionMode,
                supportsUnprocessed,
            ) { rate, bufferBytes, source ->
                createAudioRecord(rate, bufferBytes, source)
            }
            selectedRecord = selection.record
            val file = File(path).let {
                if (it.extension.lowercase() == "wav") it else File(it.parentFile, "${it.nameWithoutExtension}.wav")
            }
            file.parentFile?.mkdirs()
            if (file.exists()) file.delete()
            val openedOutput = RandomAccessFile(file, "rw")
            output = openedOutput
            openedOutput.write(ByteArray(NativeAudioHelpers.WAV_HEADER_BYTES))

            audioManager.mode = AudioManager.MODE_NORMAL
            modeChanged = true
            focusState = requestAudioFocus()
            val attachedEffects = attachProcessingEffects(
                selection.record.audioSessionId,
                config,
            )
            processingEffects = attachedEffects
            val capture = ActiveCapture(
                file = file,
                config = config,
                sampleRate = selection.sampleRate,
                bufferBytes = selection.bufferBytes,
                source = selection.source,
                record = selection.record,
                audioSessionId = selection.record.audioSessionId,
                output = openedOutput,
                startedAtMs = System.currentTimeMillis(),
                previousAudioMode = previousMode,
                focusRequest = focusState.request,
                focusAcquired = focusState.acquired,
                processingEffects = attachedEffects,
            )
            resetLevels()
            lastResult = null
            active = capture
            capture.record.startRecording()
            capture.running.set(true)
            worker = Thread({ captureLoop(capture) }, "ArchiveMeNativeAudioRecord").also { it.start() }
            result.success(startPayload(capture))
        } catch (error: Exception) {
            val ownedCapture = active
            if (ownedCapture != null) {
                ownedCapture.running.set(false)
                releaseSession(ownedCapture)
                active = null
            } else {
                processingEffects?.release()
                runCatching { selectedRecord?.release() }
                runCatching { output?.close() }
                abandonAudioFocus(focusState)
                if (modeChanged) {
                    runCatching { audioManager.mode = previousMode }
                }
            }
            result.error(
                "native_recorder_start",
                error.message ?: error.toString(),
                mapOf("step" to "record_start_failed", "reason" to error.toString(), "format" to "wav"),
            )
        }
    }

    private fun createAudioRecord(rate: Int, bufferBytes: Int, source: Int): AudioRecord {
        val record = AudioRecord(
            source,
            rate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferBytes,
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("AudioRecord failed to initialize at $rate Hz")
        }
        return record
    }

    private fun attachProcessingEffects(
        audioSessionId: Int,
        config: CaptureConfig,
    ): ProcessingEffects {
        val applied = NativeAudioHelpers.processingPolicy(
            config.sessionMode,
            config.processingRequest,
        )
        return ProcessingEffects(
            requested = config.processingRequest,
            applied = applied,
            acousticEchoCancellation = attachEffect(
                applied.acousticEchoCancellation,
                runCatching { AcousticEchoCanceler.isAvailable() }.getOrDefault(false),
            ) { AcousticEchoCanceler.create(audioSessionId) },
            noiseSuppression = attachEffect(
                applied.noiseSuppression,
                runCatching { NoiseSuppressor.isAvailable() }.getOrDefault(false),
            ) { NoiseSuppressor.create(audioSessionId) },
            automaticGainControl = attachEffect(
                applied.automaticGainControl,
                runCatching { AutomaticGainControl.isAvailable() }.getOrDefault(false),
            ) { AutomaticGainControl.create(audioSessionId) },
        )
    }

    private fun attachEffect(
        control: ProcessingControl,
        supported: Boolean,
        create: () -> AudioEffect?,
    ): ProcessingEffect {
        if (!supported || control == ProcessingControl.PLATFORM_DEFAULT) {
            return ProcessingEffect(
                effect = null,
                supported = supported,
                enabled = null,
            )
        }
        val effect = runCatching(create).getOrNull()
        if (effect == null) {
            return ProcessingEffect(effect = null, supported = false, enabled = null)
        }
        val desiredEnabled = control == ProcessingControl.ENABLED
        runCatching { effect.setEnabled(desiredEnabled) }
        val confirmedEnabled = runCatching { effect.enabled }.getOrNull()
        return ProcessingEffect(
            effect = effect,
            supported = supported,
            enabled = confirmedEnabled,
        )
    }

    private fun captureLoop(capture: ActiveCapture) {
        val samples = ShortArray(max(capture.bufferBytes / 2, 1))
        try {
            while (capture.running.get()) {
                val count = capture.record.read(samples, 0, samples.size, AudioRecord.READ_BLOCKING)
                if (count > 0) {
                    val bytes = ByteArray(count * 2)
                    var squareSum = 0.0
                    var peak = 0
                    for (index in 0 until count) {
                        val sample = samples[index].toInt()
                        bytes[index * 2] = (sample and 0xff).toByte()
                        bytes[index * 2 + 1] = ((sample ushr 8) and 0xff).toByte()
                        val absolute = kotlin.math.abs(sample)
                        peak = max(peak, absolute)
                        squareSum += sample.toDouble() * sample.toDouble()
                    }
                    capture.output.write(bytes)
                    recordLevel(
                        rmsDb = amplitudeToDb(sqrt(squareSum / count)),
                        peakDb = amplitudeToDb(peak.toDouble()),
                    )
                } else if (count < 0) {
                    break
                }
            }
        } catch (error: Throwable) {
            if (capture.running.get()) {
                capture.workerFailure = error
            }
        } finally {
            capture.running.set(false)
        }
    }

    private fun stop(): Map<String, Any> {
        lastResult?.let { return it }
        val capture = active ?: throw IllegalStateException("No active native recording")
        var successful = false
        var stopFailure: Throwable? = null
        try {
            val selectedDevice = selectedInput(capture.record)
            capture.running.set(false)
            runCatching { capture.record.stop() }
            val captureWorker = worker
            captureWorker?.join(2000)
            if (captureWorker?.isAlive == true) {
                releaseAudioRecord(capture)
                restoreAudioSession(capture)
                captureWorker.interrupt()
                captureWorker.join(1000)
            }
            if (captureWorker?.isAlive == true) {
                throw IllegalStateException(
                    "Native recorder worker did not stop; incomplete WAV was discarded",
                )
            }
            worker = null
            capture.workerFailure?.let { error ->
                throw IllegalStateException("Native recorder capture worker failed", error)
            }
            val dataBytes =
                (capture.output.length() - NativeAudioHelpers.WAV_HEADER_BYTES).coerceAtLeast(0)
            NativeAudioHelpers.writeWavHeader(
                capture.output,
                dataBytes,
                capture.sampleRate,
                channels = 1,
                bitDepth = 16,
            )
            val durationMs = System.currentTimeMillis() - capture.startedAtMs
            val average = if (sampleCount > 0) sumDb / sampleCount else -160.0
            val payload = startPayload(capture) + mapOf(
                "bytes" to capture.file.length(),
                "durationMs" to durationMs,
                "minDb" to minDb,
                "maxDb" to maxDb,
                "avgDb" to average,
                "likelySilent" to (sampleCount == 0 || maxDb < -45),
                "inputPortName" to (selectedDevice?.productName?.toString() ?: ""),
                "inputPortType" to (selectedDevice?.type?.toString() ?: ""),
            )
            lastResult = payload
            successful = true
            return payload
        } catch (error: Throwable) {
            stopFailure = error
            throw error
        } finally {
            val cleanupFailure = RecorderStopCleanup.run(
                successful = successful,
                releaseResources = { releaseSession(capture) },
                clearWorker = { worker = null },
                clearActive = { active = null },
                discardIncompleteOutput = { discardIncompleteOutput(capture.file) },
            )
            if (cleanupFailure != null) {
                if (stopFailure != null) {
                    stopFailure.addSuppressed(cleanupFailure)
                } else {
                    throw cleanupFailure
                }
            }
        }
    }

    private fun startPayload(capture: ActiveCapture): Map<String, Any> = mapOf(
        "path" to capture.file.absolutePath,
        "format" to "wav",
        "sampleRate" to capture.sampleRate,
        "channels" to 1,
        "bitDepth" to 16,
        "bufferBytes" to capture.bufferBytes,
        "bufferDurationMs" to capture.bufferBytes * 1000.0 / (capture.sampleRate * 2),
        "sessionMode" to capture.config.sessionMode,
        "audioSource" to NativeAudioHelpers.sourceName(capture.source),
        "audioSessionId" to capture.audioSessionId,
        "processing" to capture.processingEffects.payload(),
    )

    private fun levelPayload(): Map<String, Any> {
        val average = if (sampleCount > 0) sumDb / sampleCount else -160.0
        return mapOf(
            "currentDb" to latestDb,
            "peakDb" to maxDb,
            "maxDb" to maxDb,
            "avgDb" to average,
        )
    }

    private fun recordLevel(rmsDb: Double, peakDb: Double) {
        synchronized(this) {
            minDb = if (sampleCount == 0) rmsDb else kotlin.math.min(minDb, rmsDb)
            maxDb = max(maxDb, max(rmsDb, peakDb))
            sumDb += rmsDb
            sampleCount++
            latestDb = rmsDb
        }
    }

    private fun resetLevels() {
        minDb = -160.0
        maxDb = -160.0
        sumDb = 0.0
        sampleCount = 0
        latestDb = -160.0
    }

    private fun amplitudeToDb(amplitude: Double): Double =
        if (amplitude <= 0) -160.0 else max(-160.0, 20 * log10(amplitude / Short.MAX_VALUE))

    private fun selectedInput(record: AudioRecord): AudioDeviceInfo? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) record.routedDevice else null

    private fun requestAudioFocus(): AudioFocusState {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
            return AudioFocusState(
                request = null,
                acquired = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED,
            )
        }
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .build()
        val result = audioManager.requestAudioFocus(request)
        return AudioFocusState(
            request = request,
            acquired = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED,
        )
    }

    private fun abandonAudioFocus(state: AudioFocusState?) {
        if (state?.acquired != true) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && state.request != null) {
            runCatching { audioManager.abandonAudioFocusRequest(state.request) }
            return
        }
        @Suppress("DEPRECATION")
        runCatching { audioManager.abandonAudioFocus(null) }
    }

    @Synchronized
    private fun releaseAudioRecord(capture: ActiveCapture) {
        if (capture.recordReleased) return
        capture.recordReleased = true
        capture.processingEffects.release()
        runCatching { capture.record.release() }
    }

    @Synchronized
    private fun closeOutput(capture: ActiveCapture) {
        if (capture.outputClosed) return
        capture.outputClosed = true
        runCatching { capture.output.close() }
    }

    @Synchronized
    private fun restoreAudioSession(capture: ActiveCapture) {
        if (capture.audioSessionRestored) return
        capture.audioSessionRestored = true
        abandonAudioFocus(AudioFocusState(capture.focusRequest, capture.focusAcquired))
        runCatching { audioManager.mode = capture.previousAudioMode }
    }

    private fun releaseSession(capture: ActiveCapture?) {
        capture ?: return
        releaseAudioRecord(capture)
        closeOutput(capture)
        restoreAudioSession(capture)
    }

    private fun discardIncompleteOutput(file: File) {
        if (!file.exists() || file.delete()) return
        val quarantine = File(
            file.parentFile,
            "${file.name}.incomplete-${System.currentTimeMillis()}",
        )
        if (!file.renameTo(quarantine)) {
            throw IllegalStateException(
                "Failed to delete or quarantine incomplete recording at ${file.absolutePath}",
            )
        }
    }
}

internal class OnceAction(private val action: () -> Unit) {
    private val invoked = AtomicBoolean(false)

    fun run() {
        if (invoked.compareAndSet(false, true)) action()
    }
}

internal object RecorderStopCleanup {
    fun run(
        successful: Boolean,
        releaseResources: () -> Unit,
        clearWorker: () -> Unit,
        clearActive: () -> Unit,
        discardIncompleteOutput: () -> Unit,
    ): Throwable? {
        var failure: Throwable? = null

        fun cleanup(action: () -> Unit) {
            try {
                action()
            } catch (error: Throwable) {
                if (failure == null) {
                    failure = error
                } else {
                    failure.addSuppressed(error)
                }
            }
        }

        cleanup(releaseResources)
        cleanup(clearWorker)
        cleanup(clearActive)
        if (!successful) cleanup(discardIncompleteOutput)
        return failure
    }
}

internal object NativeAudioHelpers {
    const val WAV_HEADER_BYTES = 44
    private val fallbackRates = listOf(16000, 44100, 48000)

    data class Selection(
        val sampleRate: Int,
        val bufferBytes: Int,
        val source: Int,
        val record: AudioRecord,
    )

    fun selectAudioRecord(
        requestedRate: Int,
        bufferDurationMs: Double,
        sessionMode: String,
        supportsUnprocessed: Boolean,
        factory: (Int, Int, Int) -> AudioRecord,
    ): Selection {
        var lastError: Exception? = null
        for (source in sourceCandidates(sessionMode, supportsUnprocessed)) {
            for (rate in rateCandidates(requestedRate)) {
                val minimum = AudioRecord.getMinBufferSize(
                    rate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                if (minimum <= 0) continue
                val bufferBytes = calculateBufferBytes(rate, bufferDurationMs, minimum)
                try {
                    return Selection(rate, bufferBytes, source, factory(rate, bufferBytes, source))
                } catch (error: Exception) {
                    lastError = error
                }
            }
        }
        throw lastError ?: IllegalStateException("No supported microphone sample rate")
    }

    fun preferredSource(sessionMode: String, supportsUnprocessed: Boolean): Int {
        return if (
            (sessionMode == "measurement" || sessionMode == "raw") &&
            supportsUnprocessed
        ) {
            MediaRecorder.AudioSource.UNPROCESSED
        } else if (sessionMode == "spokenAudio") {
            MediaRecorder.AudioSource.VOICE_RECOGNITION
        } else {
            MediaRecorder.AudioSource.MIC
        }
    }

    fun sourceCandidates(sessionMode: String, supportsUnprocessed: Boolean): List<Int> =
        listOf(
            preferredSource(sessionMode, supportsUnprocessed),
            MediaRecorder.AudioSource.MIC,
        ).distinct()

    fun processingPolicy(
        sessionMode: String,
        requested: ProcessingRequest,
    ): ProcessingRequest {
        if (sessionMode != "measurement" && sessionMode != "raw") return requested
        return ProcessingRequest(
            acousticEchoCancellation = ProcessingControl.DISABLED,
            noiseSuppression = ProcessingControl.DISABLED,
            automaticGainControl = ProcessingControl.DISABLED,
        )
    }

    fun rateCandidates(requestedRate: Int): List<Int> =
        (listOf(requestedRate.coerceIn(8000, 192000)) + fallbackRates).distinct()

    fun calculateBufferBytes(
        sampleRate: Int,
        bufferDurationMs: Double,
        minimumBytes: Int,
    ): Int {
        val duration = bufferDurationMs.takeIf { it.isFinite() }?.coerceIn(1.0, 500.0) ?: 20.0
        val requested = (sampleRate.coerceIn(8000, 192000) * 2 * duration / 1000).toInt()
        return max(requested, minimumBytes.coerceAtLeast(1))
    }

    fun sourceName(source: Int): String = when (source) {
        MediaRecorder.AudioSource.UNPROCESSED -> "UNPROCESSED"
        MediaRecorder.AudioSource.VOICE_RECOGNITION -> "VOICE_RECOGNITION"
        else -> "MIC"
    }

    fun writeWavHeader(
        file: RandomAccessFile,
        dataBytes: Long,
        sampleRate: Int,
        channels: Int,
        bitDepth: Int,
    ) {
        val byteRate = sampleRate * channels * bitDepth / 8
        val blockAlign = channels * bitDepth / 8
        file.seek(0)
        file.writeBytes("RIFF")
        writeLittleEndian(file, dataBytes + 36, 4)
        file.writeBytes("WAVEfmt ")
        writeLittleEndian(file, 16, 4)
        writeLittleEndian(file, 1, 2)
        writeLittleEndian(file, channels.toLong(), 2)
        writeLittleEndian(file, sampleRate.toLong(), 4)
        writeLittleEndian(file, byteRate.toLong(), 4)
        writeLittleEndian(file, blockAlign.toLong(), 2)
        writeLittleEndian(file, bitDepth.toLong(), 2)
        file.writeBytes("data")
        writeLittleEndian(file, dataBytes, 4)
    }

    private fun writeLittleEndian(file: RandomAccessFile, value: Long, byteCount: Int) {
        repeat(byteCount) { index -> file.write(((value shr (index * 8)) and 0xff).toInt()) }
    }
}
