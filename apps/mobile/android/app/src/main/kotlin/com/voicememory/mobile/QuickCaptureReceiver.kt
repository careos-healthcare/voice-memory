package com.voicememory.mobile

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/// Widget tap entry point. Starts [AudioCaptureService] and leaves [MainActivity] closed.
class QuickCaptureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val service = Intent(context, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_TOGGLE
        }
        context.startForegroundService(service)
    }

    companion object {
        const val ACTION_START = "com.voicememory.mobile.action.QUICK_CAPTURE"
    }
}
