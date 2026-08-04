package com.voicememory.mobile

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.voicememory.mobile.audio.AndroidNativeVoiceRecorder
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FlutterFragmentActivity is required by local_auth for biometric prompts.
class MainActivity : FlutterFragmentActivity() {
    private val nativeAudioChannelName = "archive_me/native_audio_recorder"
    private val sensitiveTemporaryAudioChannelName =
        "archive_me/sensitive_temporary_audio_store"
    private val nativeAudioPermissionRequestCode = 4103
    private var pendingNativeAudioPermissionResult: MethodChannel.Result? = null
    private var hasRequestedNativeAudioPermission = false
    private var nativeAudioRecorder: AndroidNativeVoiceRecorder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeAudioRecorder = AndroidNativeVoiceRecorder(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativeAudioChannelName)
            .setMethodCallHandler(::handleNativeAudioMethod)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            sensitiveTemporaryAudioChannelName,
        ).setMethodCallHandler { call, result ->
            if (call.method != "protectedDirectory") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val directory = File(noBackupFilesDir, "sensitive_temporary_audio")
                if ((!directory.exists() && !directory.mkdirs()) || !directory.isDirectory) {
                    result.error("storage_unavailable", "Protected audio storage unavailable.", null)
                } else {
                    result.success(directory.canonicalPath)
                }
            } catch (_: Exception) {
                result.error("storage_unavailable", "Protected audio storage unavailable.", null)
            }
        }
    }

    private fun handleNativeAudioMethod(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "nativeMicrophonePermission") {
            result.success(
                nativeAudioRecorder?.permissionPayload(
                    canRequest = !hasRequestedNativeAudioPermission ||
                        shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO),
                ),
            )
            return
        }
        if (call.method != "requestNativeMicrophonePermission") {
            nativeAudioRecorder?.handle(call, result) ?: result.notImplemented()
            return
        }
        if (hasNativeAudioPermission()) {
            result.success(nativeAudioRecorder?.permissionPayload(canRequest = false))
            return
        }
        if (pendingNativeAudioPermissionResult != null) {
            result.error("request_in_progress", "Microphone permission request already active", null)
            return
        }
        pendingNativeAudioPermissionResult = result
        hasRequestedNativeAudioPermission = true
        requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            nativeAudioPermissionRequestCode,
        )
    }

    private fun hasNativeAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == nativeAudioPermissionRequestCode) {
            pendingNativeAudioPermissionResult?.success(
                nativeAudioRecorder?.permissionPayload(
                    canRequest = !hasNativeAudioPermission() &&
                        shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO),
                ),
            )
            pendingNativeAudioPermissionResult = null
        }
    }

    override fun onStop() {
        if (!isChangingConfigurations) nativeAudioRecorder?.onBackground()
        super.onStop()
    }

    override fun onDestroy() {
        nativeAudioRecorder?.dispose()
        nativeAudioRecorder = null
        pendingNativeAudioPermissionResult?.error(
            "activity_destroyed",
            "Microphone permission request was interrupted",
            null,
        )
        pendingNativeAudioPermissionResult = null
        super.onDestroy()
    }
}
