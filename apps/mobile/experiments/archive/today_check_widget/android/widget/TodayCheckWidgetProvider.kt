package com.voicememory.mobile.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.voicememory.mobile.MainActivity
import com.voicememory.mobile.R

class TodayCheckWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayCheckWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            val intent = Intent(context, TodayCheckWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}

private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
) {
    val payload = ObjectiveWidgetStorage.readPayload(context)
    val views = RemoteViews(context.packageName, R.layout.today_check_widget)

    views.setTextViewText(R.id.widget_title, payload["title"] ?: "")
    views.setTextViewText(R.id.widget_body, payload["body"] ?: "")

    val checkQuestion = payload["checkQuestion"]?.trim().orEmpty()
    if (checkQuestion.isEmpty()) {
        views.setViewVisibility(R.id.widget_check_question, View.GONE)
    } else {
        views.setViewVisibility(R.id.widget_check_question, View.VISIBLE)
        views.setTextViewText(R.id.widget_check_question, checkQuestion)
    }

    views.setTextViewText(
        R.id.widget_action,
        payload["primaryActionLabel"] ?: "Open",
    )

    val route = payload["route"]?.trim().takeUnless { it.isNullOrEmpty() } ?: "/record"
    val launchIntent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra(ObjectiveWidgetStorage.EXTRA_WIDGET_ROUTE, route)
    }
    val pendingIntent = PendingIntent.getActivity(
        context,
        appWidgetId,
        launchIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

    appWidgetManager.updateAppWidget(appWidgetId, views)
}
