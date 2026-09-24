package com.voicememory.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    private val legacyCleanupChannelName = "archive_me/excluded_capability_cleanup"
    private val compressorChannelName = "archive_me/capture_audio_compressor"
    private val shareImportChannelName = "com.archiveme/share_import"
    private val nativeSpeechChannelName = "archive_me/native_speech_transcription"
    private val hardwareMonitorChannelName = "archive_me/hardware_monitor"
    private val hardwareSnapshotChannelName = "com.archiveme/hardware_monitor"
    private val quickActionsChannelName = "com.archiveme/quick_actions"
    private var quickActionsChannel: MethodChannel? = null
    private var pendingQuickAction: String? = null
    private var shareImportChannel: MethodChannel? = null
    private val pendingImportPaths = ArrayDeque<String>()
    private var shareImportReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, legacyCleanupChannelName)
            .setMethodCallHandler(::handleLegacyCleanupMethod)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, compressorChannelName)
            .setMethodCallHandler(::handleCompressorMethod)
        CaptureAudioCompressorHandler.register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ZeroStateMicrophoneHandler.channelName,
        ).setMethodCallHandler { call, result ->
            ZeroStateMicrophoneHandler.handle(this, call, result)
        }
        shareImportChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareImportChannelName,
        ).also { channel ->
            channel.setMethodCallHandler(::handleShareImportMethod)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativeSpeechChannelName)
            .setMethodCallHandler(::handleNativeSpeechMethod)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hardwareMonitorChannelName)
            .setMethodCallHandler(::handleHardwareMonitorMethod)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hardwareSnapshotChannelName)
            .setMethodCallHandler(::handleHardwareMonitorMethod)
        quickActionsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            quickActionsChannelName,
        ).also { channel ->
            channel.setMethodCallHandler(::handleQuickActionMethod)
        }
        dispatchQuickAction()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        clearLegacyWidgetSharedPreferences(this)
        rememberQuickAction(intent)
        beginShortcutBuffer(intent)
        rememberSharedImport(intent)
        dispatchQuickAction()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        rememberQuickAction(intent)
        beginShortcutBuffer(intent)
        rememberSharedImport(intent)
        dispatchQuickAction()
    }

    private fun beginShortcutBuffer(intent: Intent?) {
        ShortcutAudioBuffer.note(intent)
        if (ShortcutAudioBuffer.isRecordLaunch(intent)) {
            ShortcutAudioBuffer.begin(this)
        }
    }

    private fun rememberQuickAction(intent: Intent?) {
        val action = intent?.getStringExtra(QUICK_ACTION_EXTRA) ?: return
        if (action != START_RECORDING) return
        pendingQuickAction = action
    }

    private fun dispatchQuickAction() {
        val action = pendingQuickAction ?: return
        quickActionsChannel?.invokeMethod("onQuickAction", action)
    }

    private fun rememberSharedImport(intent: Intent?) {
        val paths = copySharedImports(intent)
        if (paths.isEmpty()) return
        if (shareImportReady) {
            paths.forEach { path -> shareImportChannel?.invokeMethod("shareImportReady", path) }
        } else {
            pendingImportPaths.addAll(paths)
        }
    }

    @Suppress("DEPRECATION")
    private fun copySharedImports(intent: Intent?): List<String> {
        if (intent == null) return emptyList()
        val sources = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri,
            )
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            else -> emptyList()
        }
        return sources.mapNotNull { copyStreamToImports(it) }
    }

    private fun copyStreamToImports(source: Uri): String? {
        return try {
            val dir = java.io.File(filesDir, "imports").apply { mkdirs() }
            val name = sanitizedName(source)
            var dest = java.io.File(dir, name)
            if (dest.exists()) {
                val stamp = System.nanoTime()
                val dot = name.lastIndexOf('.')
                val unique = if (dot > 0) {
                    name.substring(0, dot) + "-$stamp" + name.substring(dot)
                } else {
                    "$name-$stamp"
                }
                dest = java.io.File(dir, unique)
            }
            contentResolver.openInputStream(source)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            if (!dest.exists() || dest.length() <= 0L) return null
            dest.absolutePath
        } catch (error: Exception) {
            null
        }
    }

    private fun sanitizedName(source: Uri): String {
        val queried = contentResolver.query(
            source,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
        val raw = queried?.takeIf { it.isNotBlank() }
            ?: source.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
            ?: "import-${System.currentTimeMillis()}"
        return raw.substringAfterLast('/').substringAfterLast('\\').ifBlank {
            "import-${System.currentTimeMillis()}"
        }
    }

    private fun handleShareImportMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "consumePendingImport" -> {
                shareImportReady = true
                val first = pendingImportPaths.removeFirstOrNull()
                val rest = pendingImportPaths.toList()
                pendingImportPaths.clear()
                result.success(first)
                rest.forEach { path -> shareImportChannel?.invokeMethod("shareImportReady", path) }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleQuickActionMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "consumePendingQuickAction" -> {
                result.success(pendingQuickAction)
                pendingQuickAction = null
            }
            else -> result.notImplemented()
        }
    }

    private fun handleLegacyCleanupMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "clearLegacyWidgetSharedData" -> {
                clearLegacyWidgetSharedPreferences(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleCompressorMethod(call: MethodCall, result: MethodChannel.Result) {
        CaptureAudioCompressorHandler.handle(call, result)
    }

    private fun handleNativeSpeechMethod(call: MethodCall, result: MethodChannel.Result) {
        NativeSpeechTranscriptionHandler.handle(this, call, result)
    }

    private fun handleHardwareMonitorMethod(call: MethodCall, result: MethodChannel.Result) {
        HardwareMonitorHandler.handle(this, call, result)
    }

    companion object {
        const val QUICK_ACTION_EXTRA = "quick_action"
        const val START_RECORDING = "start_recording"
        private const val LEGACY_WIDGET_PREFS = "archive_me_today_check_widget"

        fun clearLegacyWidgetSharedPreferences(context: Context) {
            context.getSharedPreferences(LEGACY_WIDGET_PREFS, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .apply()
        }
    }
}
