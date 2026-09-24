package com.voicememory.mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/// Home-screen widget that opens ArchiveMe on the recording screen.
///
/// The tap uses [HomeWidgetLaunchIntent], so Flutter receives
/// `archiveme://record?homeWidget` from `HomeWidget.widgetClicked`.
class RecordLaunchWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val pending = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("archiveme://record?homeWidget&autostart=1"),
        )
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_record_launch)
            views.setOnClickPendingIntent(R.id.widget_record_launch, pending)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
