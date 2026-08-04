package com.voicememory.mobile.widget

import android.content.Context
import com.voicememory.mobile.integration.SecureNativeStorage
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal object AndroidWidgetStorage {
    private const val AAD = "android-widget-state:v1"

    fun update(context: Context, payload: Map<*, *>) = mutate(context) { state ->
        payload.forEach { (key, value) ->
            val safeKey = key?.toString()?.takeIf(ALLOWED_KEYS::contains) ?: return@forEach
            when (value) {
                is Boolean, is Number -> state.put(safeKey, value)
                is Map<*, *> -> state.put(safeKey, JSONObject(value))
                is Iterable<*> -> state.put(safeKey, JSONArray(value.toList()))
                null -> state.remove(safeKey)
                else -> state.put(safeKey, value.toString().take(MAX_VALUE_CHARS))
            }
        }
        state
    }

    fun completeHabit(context: Context) = mutate(context) { state ->
        val stepId = state.optString("habitStepId").trim()
        if (stepId.isEmpty() || state.optBoolean("habitCompleted", false)) {
            return@mutate state
        }
        state.put("habitCompleted", true)
        state.put(
            "pendingAction",
            JSONObject()
                .put("type", "completeHabit")
                .put("stepId", stepId)
                .put(
                    "localDay",
                    SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()),
                ),
        )
        state
    }

    fun recordClusterPulse(context: Context) = mutate(context) { state ->
        state.put(
            "pendingAction",
            JSONObject()
                .put("type", "semanticClusterPulse")
                .put("createdAt", System.currentTimeMillis()),
        )
        state
    }

    fun consumePendingAction(context: Context): Map<String, Any?>? {
        var consumed: Map<String, Any?>? = null
        mutate(context) { state ->
            val action = state.optJSONObject("pendingAction")
            if (action != null) {
                consumed = action.keys().asSequence().associateWith { key ->
                    when (val value = action.get(key)) {
                        JSONObject.NULL -> null
                        else -> value
                    }
                }
                state.remove("pendingAction")
            }
            state
        }
        return consumed
    }

    fun snapshot(context: Context): JSONObject = SecureNativeStorage.locked(context) {
        readUnlocked(context)
    }

    private fun mutate(context: Context, transform: (JSONObject) -> JSONObject) {
        SecureNativeStorage.locked(context) {
            val updated = transform(readUnlocked(context))
            SecureNativeStorage.writeEncryptedAtomic(file(context), AAD) { output ->
                output.write(updated.toString().toByteArray(Charsets.UTF_8))
            }
        }
    }

    private fun readUnlocked(context: Context): JSONObject {
        val file = file(context)
        if (!file.isFile) return defaults()
        return runCatching {
            SecureNativeStorage.readEncrypted(file, AAD)
                .bufferedReader(Charsets.UTF_8)
                .use { JSONObject(it.readText()) }
        }.getOrElse {
            file.delete()
            defaults()
        }
    }

    private fun file(context: Context) =
        File(context.noBackupFilesDir, "native_os/widgets/state.enc")

    private fun defaults() = JSONObject()
        .put("quickCaptureLabel", "Quick capture")
        .put("quickCaptureRoute", "/record")
        .put("habitTitle", "Micro-habit")
        .put("habitCompleted", false)
        .put("habitRoute", "/")
        .put("clusterTitle", "Memory pulse")
        .put("clusterSummary", "Open your semantic clusters")
        .put("clusterRoute", "/")

    private const val MAX_VALUE_CHARS = 2_048
    private val ALLOWED_KEYS = setOf(
        "quickCaptureLabel",
        "quickCaptureRoute",
        "habitTitle",
        "habitCompleted",
        "habitStepId",
        "habitRoute",
        "clusterTitle",
        "clusterSummary",
        "clusterRoute",
        "theme",
        "schemaVersion",
        "generatedAt",
        "lockScreenEnabled",
        "quickCapture",
        "habits",
        "clusters",
        "habitStreak",
        "clusterPulse",
    )
}
