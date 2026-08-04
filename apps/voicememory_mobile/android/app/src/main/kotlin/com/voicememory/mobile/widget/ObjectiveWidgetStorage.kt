package com.voicememory.mobile.widget

import android.content.Context
import com.voicememory.mobile.integration.SecureNativeStorage
import org.json.JSONObject
import java.io.File

object ObjectiveWidgetStorage {
    const val PREFS_NAME = "archive_me_today_check_widget"
    const val EXTRA_WIDGET_ROUTE = "archive_me_widget_route"
    private const val AAD = "today-check-widget:v1"

    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_CHECK_QUESTION = "checkQuestion"
    private const val KEY_PRIMARY_ACTION = "primaryActionLabel"
    private const val KEY_ROUTE = "route"
    private const val KEY_TYPE = "type"
    private const val KEY_UPDATED_AT = "updatedAt"

    fun save(context: Context, payload: Map<*, *>) {
        SecureNativeStorage.locked(context) {
            eraseLegacyPlaintext(context)
            val value = JSONObject()
                .put(KEY_TITLE, bounded(payload[KEY_TITLE]))
                .put(KEY_BODY, bounded(payload[KEY_BODY]))
                .put(KEY_CHECK_QUESTION, bounded(payload[KEY_CHECK_QUESTION]))
                .put(KEY_PRIMARY_ACTION, bounded(payload[KEY_PRIMARY_ACTION]))
                .put(KEY_ROUTE, bounded(payload[KEY_ROUTE], "/record"))
                .put(KEY_TYPE, bounded(payload[KEY_TYPE]))
                .put(KEY_UPDATED_AT, bounded(payload[KEY_UPDATED_AT]))
            SecureNativeStorage.writeEncryptedAtomic(file(context), AAD) {
                it.write(value.toString().toByteArray(Charsets.UTF_8))
            }
        }
    }

    fun clear(context: Context) {
        SecureNativeStorage.locked(context) {
            eraseLegacyPlaintext(context)
            file(context).delete()
        }
    }

    fun readPayload(context: Context): Map<String, String> = SecureNativeStorage.locked(context) {
        eraseLegacyPlaintext(context)
        val stored = runCatching {
            SecureNativeStorage.readEncrypted(file(context), AAD)
                .bufferedReader(Charsets.UTF_8)
                .use { JSONObject(it.readText()) }
        }.getOrNull() ?: return@locked defaultPayload()
        val title = stored.optString(KEY_TITLE)
        val body = stored.optString(KEY_BODY)
        if (title.isBlank() && body.isBlank()) {
            return@locked defaultPayload()
        }
        mapOf(
            KEY_TITLE to title,
            KEY_BODY to body,
            KEY_CHECK_QUESTION to stored.optString(KEY_CHECK_QUESTION),
            KEY_PRIMARY_ACTION to stored.optString(KEY_PRIMARY_ACTION, "Open"),
            KEY_ROUTE to stored.optString(KEY_ROUTE, "/record"),
            KEY_TYPE to stored.optString(KEY_TYPE),
            KEY_UPDATED_AT to stored.optString(KEY_UPDATED_AT),
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

    private fun bounded(value: Any?, fallback: String = "") =
        (value?.toString() ?: fallback).take(2_048)

    private fun file(context: Context) =
        File(context.noBackupFilesDir, "native_os/widgets/today_check.enc")

    private fun eraseLegacyPlaintext(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().commit()
    }
}
