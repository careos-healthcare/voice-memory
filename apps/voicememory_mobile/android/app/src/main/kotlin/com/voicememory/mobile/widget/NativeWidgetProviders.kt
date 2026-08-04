package com.voicememory.mobile.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import com.voicememory.mobile.MainActivity
import com.voicememory.mobile.R

class QuickCaptureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = AndroidWidgetStorage.snapshot(context)
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.quick_capture_widget)
            val privateOnKeyguard = WidgetPrivacy.isPrivateOnKeyguard(manager, id, state)
            views.setTextViewText(
                R.id.quick_capture_action,
                if (privateOnKeyguard) {
                    context.getString(R.string.widget_private)
                } else {
                    state.optString("quickCaptureLabel", "Quick capture")
                },
            )
            views.setTextColor(R.id.quick_capture_action, WidgetTheme.textColor(state))
            views.setOnClickPendingIntent(
                R.id.quick_capture_root,
                WidgetIntents.openRoute(
                    context,
                    id * 10 + 1,
                    if (privateOnKeyguard) "/" else state.optString("quickCaptureRoute", "/record"),
                ),
            )
            manager.updateAppWidget(id, views)
        }
    }
}

class MicroHabitWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = AndroidWidgetStorage.snapshot(context)
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.micro_habit_widget)
            val privateOnKeyguard = WidgetPrivacy.isPrivateOnKeyguard(manager, id, state)
            val completed = state.optBoolean("habitCompleted", false)
            views.setTextViewText(
                R.id.micro_habit_title,
                if (privateOnKeyguard) {
                    context.getString(R.string.widget_private)
                } else {
                    state.optString("habitTitle", "Micro-habit")
                },
            )
            views.setTextViewText(
                R.id.micro_habit_toggle,
                if (privateOnKeyguard) {
                    context.getString(R.string.widget_unlock_to_view)
                } else {
                    context.getString(if (completed) R.string.habit_done else R.string.habit_not_done)
                },
            )
            views.setTextColor(R.id.micro_habit_title, WidgetTheme.textColor(state))
            views.setTextColor(R.id.micro_habit_toggle, WidgetTheme.accentColor(state))
            val stepId = state.optString("habitStepId").trim()
            views.setOnClickPendingIntent(
                R.id.micro_habit_toggle,
                if (!privateOnKeyguard && stepId.isNotEmpty() && !completed) {
                    WidgetIntents.broadcast(
                        context,
                        id * 10 + 2,
                        MicroHabitWidgetProvider::class.java,
                        WidgetIntents.ACTION_COMPLETE_HABIT,
                    )
                } else {
                    WidgetIntents.openRoute(
                        context,
                        id * 10 + 2,
                        if (privateOnKeyguard) "/" else state.optString("habitRoute", "/"),
                    )
                },
            )
            views.setOnClickPendingIntent(
                R.id.micro_habit_title,
                WidgetIntents.openRoute(
                    context,
                    id * 10 + 3,
                    state.optString("habitRoute", "/"),
                ),
            )
            manager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetIntents.ACTION_COMPLETE_HABIT) {
            AndroidWidgetStorage.completeHabit(context)
            AndroidWidgets.requestUpdates(context)
        }
    }
}

class SemanticClusterWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = AndroidWidgetStorage.snapshot(context)
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.semantic_cluster_widget)
            val privateOnKeyguard = WidgetPrivacy.isPrivateOnKeyguard(manager, id, state)
            views.setTextViewText(
                R.id.semantic_cluster_title,
                if (privateOnKeyguard) {
                    context.getString(R.string.widget_private)
                } else {
                    state.optString("clusterTitle", "Memory pulse")
                },
            )
            views.setTextViewText(
                R.id.semantic_cluster_summary,
                if (privateOnKeyguard) {
                    context.getString(R.string.widget_unlock_to_view)
                } else {
                    state.optString("clusterSummary", "Open your semantic clusters")
                },
            )
            views.setTextColor(R.id.semantic_cluster_title, WidgetTheme.textColor(state))
            views.setTextColor(R.id.semantic_cluster_summary, WidgetTheme.secondaryColor(state))
            views.setOnClickPendingIntent(
                R.id.semantic_cluster_root,
                WidgetIntents.openRoute(
                    context,
                    id * 10 + 4,
                    if (privateOnKeyguard) "/" else state.optString("clusterRoute", "/"),
                ),
            )
            views.setOnClickPendingIntent(
                R.id.semantic_cluster_pulse,
                if (privateOnKeyguard) {
                    WidgetIntents.openRoute(context, id * 10 + 5, "/")
                } else {
                    WidgetIntents.broadcast(
                        context,
                        id * 10 + 5,
                        SemanticClusterWidgetProvider::class.java,
                        WidgetIntents.ACTION_CLUSTER_PULSE,
                    )
                },
            )
            manager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetIntents.ACTION_CLUSTER_PULSE) {
            AndroidWidgetStorage.recordClusterPulse(context)
            AndroidWidgets.requestUpdates(context)
        }
    }
}

private object WidgetPrivacy {
    fun isPrivateOnKeyguard(
        manager: AppWidgetManager,
        appWidgetId: Int,
        state: org.json.JSONObject,
    ): Boolean {
        if (state.optBoolean("lockScreenEnabled", false)) return false
        val category = manager.getAppWidgetOptions(appWidgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY, 0)
        return category == AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD
    }
}

private object WidgetTheme {
    fun textColor(state: org.json.JSONObject): Int = when (state.optString("theme")) {
        "sunrise" -> Color.rgb(69, 38, 22)
        "highContrast" -> Color.WHITE
        "midnight" -> Color.rgb(232, 238, 255)
        else -> Color.rgb(36, 36, 40)
    }

    fun secondaryColor(state: org.json.JSONObject): Int = when (state.optString("theme")) {
        "sunrise" -> Color.rgb(118, 68, 39)
        "highContrast" -> Color.YELLOW
        "midnight" -> Color.rgb(174, 186, 222)
        else -> Color.rgb(92, 92, 100)
    }

    fun accentColor(state: org.json.JSONObject): Int = when (state.optString("theme")) {
        "sunrise" -> Color.rgb(178, 74, 34)
        "highContrast" -> Color.YELLOW
        "midnight" -> Color.rgb(135, 160, 255)
        else -> Color.rgb(76, 94, 210)
    }
}

internal object AndroidWidgets {
    fun requestUpdates(context: Context) {
        request(context, QuickCaptureWidgetProvider::class.java)
        request(context, MicroHabitWidgetProvider::class.java)
        request(context, SemanticClusterWidgetProvider::class.java)
    }

    private fun request(context: Context, provider: Class<out AppWidgetProvider>) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, provider)
        val ids = manager.getAppWidgetIds(component)
        if (ids.isEmpty()) return
        context.sendBroadcast(
            Intent(context, provider).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            },
        )
    }
}

private object WidgetIntents {
    const val ACTION_COMPLETE_HABIT = "com.voicememory.mobile.widget.COMPLETE_HABIT"
    const val ACTION_CLUSTER_PULSE = "com.voicememory.mobile.widget.CLUSTER_PULSE"

    fun openRoute(context: Context, requestCode: Int, route: String): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(ObjectiveWidgetStorage.EXTRA_WIDGET_ROUTE, route.take(512))
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun broadcast(
        context: Context,
        requestCode: Int,
        provider: Class<out AppWidgetProvider>,
        actionName: String,
    ): PendingIntent = PendingIntent.getBroadcast(
        context,
        requestCode,
        Intent(context, provider).setAction(actionName),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
