package com.voicememory.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import java.io.File

/// Records from the microphone while the app UI stays closed.
class AudioCaptureService : Service() {
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopCapture()
            else -> if (recorder == null) startCapture() else stopCapture()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseRecorder(discardFile = false)
        super.onDestroy()
    }

    private fun startCapture() {
        val notification = recordingNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val directory = getExternalFilesDir(null) ?: filesDir
        val file = File(directory, "quick-capture-${System.currentTimeMillis()}.m4a")
        val media = createRecorder()
        try {
            media.setAudioSource(MediaRecorder.AudioSource.MIC)
            media.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            media.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            media.setOutputFile(file.absolutePath)
            media.prepare()
            media.start()
            recorder = media
            outputFile = file
        } catch (_: RuntimeException) {
            media.release()
            file.delete()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun stopCapture() {
        releaseRecorder(discardFile = false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releaseRecorder(discardFile: Boolean) {
        val media = recorder
        recorder = null
        if (media != null) {
            try {
                media.stop()
            } catch (_: RuntimeException) {
                outputFile?.delete()
            }
            media.release()
        }
        if (discardFile) outputFile?.delete()
        outputFile = null
    }

    private fun createRecorder(): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }

    private fun recordingNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Recording",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val stop = Intent(this, AudioCaptureService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            STOP_REQUEST_CODE,
            stop,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopAction = Notification.Action.Builder(
            Icon.createWithResource(this, R.mipmap.ic_launcher),
            "Stop",
            stopPending,
        ).build()
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording")
            .setContentText("Recording from the home screen.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(stopAction)
            .build()
    }

    companion object {
        const val ACTION_TOGGLE = "com.voicememory.mobile.action.TOGGLE_CAPTURE"
        const val ACTION_STOP = "com.voicememory.mobile.action.STOP_CAPTURE"
        private const val CHANNEL_ID = "quick_capture_recording"
        private const val NOTIFICATION_ID = 41
        private const val STOP_REQUEST_CODE = 28
    }
}
