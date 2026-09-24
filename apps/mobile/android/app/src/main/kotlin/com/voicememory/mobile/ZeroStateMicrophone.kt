package com.voicememory.mobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Opens the microphone path as soon as the Flutter app becomes active.
object ZeroStateMicrophone {
    fun prime(context: Context, alreadyRecording: Boolean): Boolean {
        val granted = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted || alreadyRecording) return granted
        val buffer = AudioRecord.getMinBufferSize(
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (buffer <= 0) return false
        val record = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            buffer,
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return false
        }
        return try {
            record.startRecording()
            record.stop()
            true
        } catch (_: IllegalStateException) {
            false
        } finally {
            record.release()
        }
    }
}

object ZeroStateMicrophoneHandler {
    const val channelName = "com.archiveme/zero_state_recorder"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "primeMicrophone" -> {
                val args = call.arguments as? Map<*, *>
                val alreadyRecording = args?.get("alreadyRecording") as? Boolean ?: false
                result.success(ZeroStateMicrophone.prime(context, alreadyRecording))
            }
            ShortcutAudioBuffer.consumeMethod -> result.success(ShortcutAudioBuffer.consumeLaunch())
            ShortcutAudioBuffer.beginMethod -> {
                ShortcutAudioBuffer.begin(context)
                result.success(true)
            }
            ShortcutAudioBuffer.releaseMethod -> result.success(ShortcutAudioBuffer.release())
            else -> result.notImplemented()
        }
    }
}

/// Holds the microphone open when a shortcut or lock-screen widget launched the app.
object ShortcutAudioBuffer {
    const val consumeMethod = "consumeRecordLaunch"
    const val beginMethod = "beginAudioBuffer"
    const val releaseMethod = "releaseAudioBuffer"
    const val QUICK_ACTION_EXTRA = "quick_action"
    const val START_RECORDING = "start_recording"

    private var pendingLaunch = false
    private var record: AudioRecord? = null
    private var reader: Thread? = null
    @Volatile private var running = false
    private var outputPath: String? = null

    fun note(intent: Intent?) {
        if (!isRecordLaunch(intent)) return
        pendingLaunch = true
    }

    fun isRecordLaunch(intent: Intent?): Boolean {
        if (intent?.getStringExtra(QUICK_ACTION_EXTRA) == START_RECORDING) {
            return true
        }
        val data = intent?.data ?: return false
        return data.scheme.equals("archiveme", ignoreCase = true) &&
            data.host.equals("record", ignoreCase = true)
    }

    fun consumeLaunch(): Boolean {
        val pending = pendingLaunch
        pendingLaunch = false
        return pending
    }

    fun begin(context: Context) {
        if (running) return
        val granted = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) return
        val buffer = AudioRecord.getMinBufferSize(
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (buffer <= 0) return
        val audio = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            buffer,
        )
        if (audio.state != AudioRecord.STATE_INITIALIZED) {
            audio.release()
            return
        }
        val file = java.io.File(context.cacheDir, "shortcut-buffer-${System.currentTimeMillis()}.pcm")
        audio.startRecording()
        running = true
        record = audio
        outputPath = file.absolutePath
        reader = Thread {
            val bytes = ByteArray(buffer)
            java.io.FileOutputStream(file).use { output ->
                while (running) {
                    val read = audio.read(bytes, 0, bytes.size)
                    if (read > 0) output.write(bytes, 0, read)
                }
            }
        }.also { it.start() }
    }

    fun release(): String? {
        running = false
        val audio = record
        record = null
        try {
            audio?.stop()
        } catch (_: IllegalStateException) {
        }
        audio?.release()
        reader?.join(500)
        reader = null
        val path = outputPath
        outputPath = null
        return path
    }
}
