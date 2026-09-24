package com.voicememory.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/// Home-screen mic. The tap broadcasts to [QuickCaptureReceiver], which starts
/// [AudioCaptureService] without opening [MainActivity].
class QuickCaptureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val launch = Intent(context, QuickCaptureReceiver::class.java).apply {
            action = QuickCaptureReceiver.ACTION_START
        }
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_capture)
            views.setOnClickPendingIntent(R.id.widget_quick_capture_mic, pending)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private companion object {
        const val REQUEST_CODE = 27
    }
}
