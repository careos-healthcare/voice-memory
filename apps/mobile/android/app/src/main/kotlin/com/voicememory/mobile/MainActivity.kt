package com.voicememory.mobile

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    private val legacyCleanupChannelName = "archive_me/excluded_capability_cleanup"
    private val compressorChannelName = "archive_me/capture_audio_compressor"
    private val nativeSpeechChannelName = "archive_me/native_speech_transcription"
    private val hardwareMonitorChannelName = "archive_me/hardware_monitor"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, legacyCleanupChannelName)
            .setMethodCallHandler(::handleLegacyCleanupMethod)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, compressorChannelName)
            .setMethodCallHandler(::handleCompressorMethod)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativeSpeechChannelName)
            .setMethodCallHandler(::handleNativeSpeechMethod)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hardwareMonitorChannelName)
            .setMethodCallHandler(::handleHardwareMonitorMethod)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        clearLegacyWidgetSharedPreferences(this)
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
        private const val LEGACY_WIDGET_PREFS = "archive_me_today_check_widget"

        fun clearLegacyWidgetSharedPreferences(context: Context) {
            context.getSharedPreferences(LEGACY_WIDGET_PREFS, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .apply()
        }
    }
}
