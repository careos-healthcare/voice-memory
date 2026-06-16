package com.voicememory.app.widget

import android.content.Context

object ObjectiveWidgetStorage {
    const val PREFS_NAME = "archive_me_today_check_widget"
    const val EXTRA_WIDGET_ROUTE = "archive_me_widget_route"

    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_CHECK_QUESTION = "checkQuestion"
    private const val KEY_PRIMARY_ACTION = "primaryActionLabel"
    private const val KEY_ROUTE = "route"
    private const val KEY_TYPE = "type"
    private const val KEY_UPDATED_AT = "updatedAt"

    fun save(context: Context, payload: Map<*, *>) {
        prefs(context).edit()
            .putString(KEY_TITLE, payload[KEY_TITLE]?.toString() ?: "")
            .putString(KEY_BODY, payload[KEY_BODY]?.toString() ?: "")
            .putString(
                KEY_CHECK_QUESTION,
                payload[KEY_CHECK_QUESTION]?.toString() ?: "",
            )
            .putString(
                KEY_PRIMARY_ACTION,
                payload[KEY_PRIMARY_ACTION]?.toString() ?: "",
            )
            .putString(KEY_ROUTE, payload[KEY_ROUTE]?.toString() ?: "/record")
            .putString(KEY_TYPE, payload[KEY_TYPE]?.toString() ?: "")
            .putString(KEY_UPDATED_AT, payload[KEY_UPDATED_AT]?.toString() ?: "")
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun readPayload(context: Context): Map<String, String> {
        val stored = prefs(context)
        val title = stored.getString(KEY_TITLE, "") ?: ""
        val body = stored.getString(KEY_BODY, "") ?: ""
        if (title.isBlank() && body.isBlank()) {
            return defaultPayload()
        }
        return mapOf(
            KEY_TITLE to title,
            KEY_BODY to body,
            KEY_CHECK_QUESTION to (stored.getString(KEY_CHECK_QUESTION, "") ?: ""),
            KEY_PRIMARY_ACTION to (
                stored.getString(KEY_PRIMARY_ACTION, "Open") ?: "Open"
                ),
            KEY_ROUTE to (stored.getString(KEY_ROUTE, "/record") ?: "/record"),
            KEY_TYPE to (stored.getString(KEY_TYPE, "") ?: ""),
            KEY_UPDATED_AT to (stored.getString(KEY_UPDATED_AT, "") ?: ""),
        )
    }

    private fun defaultPayload(): Map<String, String> = mapOf(
        KEY_TITLE to "Today\u2019s check",
        KEY_BODY to "Open ArchiveMe to continue.",
        KEY_CHECK_QUESTION to "",
        KEY_PRIMARY_ACTION to "Open",
        KEY_ROUTE to "/record",
        KEY_TYPE to "",
        KEY_UPDATED_AT to "",
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
