package com.voicememory.mobile

import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/// Copies ACTION_SEND / ACTION_SEND_MULTIPLE audio into app storage.
object VoiceMemoShareIntake {
    private val pending = mutableListOf<Map<String, String>>()
    private val extensions = setOf("m4a", "mp3", "wav", "ogg")

    fun capture(context: Context, intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val mime = intent.type ?: return
        if (mime != "audio/*" && !mime.startsWith("audio/")) return
        for (uri in streamUris(intent)) {
            val name = displayName(context, uri)
            val ext = extensionOf(name, mime)
            if (ext !in extensions) continue
            val copied = copy(context, uri, ext) ?: continue
            val row = mutableMapOf(
                "path" to copied.absolutePath,
                "createdAt" to recordingDate(copied),
            )
            val title = name.substringBeforeLast('.').trim()
            if (title.isNotEmpty()) row["name"] = title
            pending.add(row)
        }
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takePending" -> result.success(if (pending.isEmpty()) null else pending.removeAt(0))
            "takeQueue" -> {
                val rows = pending.toList()
                pending.clear()
                result.success(rows)
            }
            "creationDate" -> {
                val path = (call.arguments as? Map<*, *>)?.get("path") as? String
                if (path.isNullOrEmpty()) {
                    result.success(null)
                } else {
                    result.success(recordingDate(File(path)))
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun streamUris(intent: Intent): List<Uri> {
        return when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(parcel(intent))
            Intent.ACTION_SEND_MULTIPLE -> parcels(intent)
            else -> emptyList()
        }
    }

    private fun parcel(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun parcels(intent: Intent): List<Uri> {
        val list = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
        return list ?: emptyList()
    }

    private fun displayName(context: Context, uri: Uri): String {
        val cursor = context.contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && it.moveToFirst()) {
                val name = it.getString(index)
                if (!name.isNullOrBlank()) return name
            }
        }
        return uri.lastPathSegment ?: "memo.m4a"
    }

    private fun extensionOf(name: String, mime: String): String {
        val fromName = name.substringAfterLast('.', "").lowercase(Locale.US)
        if (fromName in extensions) return fromName
        return when (mime) {
            "audio/mpeg" -> "mp3"
            "audio/wav", "audio/x-wav" -> "wav"
            "audio/ogg" -> "ogg"
            else -> "m4a"
        }
    }

    private fun copy(context: Context, uri: Uri, ext: String): File? {
        return try {
            val folder = File(context.filesDir, "voice-memos")
            folder.mkdirs()
            val dest = File(folder, "${UUID.randomUUID()}.$ext")
            context.contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            dest
        } catch (_: Exception) {
            null
        }
    }

    private fun recordingDate(file: File): String {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            val raw = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE)
            parseMetadataDate(raw)?.let { return it }
        } catch (_: Exception) {
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
        return iso(Date(file.lastModified()))
    }

    private fun parseMetadataDate(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val patterns = listOf("yyyyMMdd'T'HHmmss.SSS'Z'", "yyyyMMdd'T'HHmmss")
        for (pattern in patterns) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US)
                format.timeZone = TimeZone.getTimeZone("UTC")
                val date = format.parse(raw) ?: continue
                return iso(date)
            } catch (_: Exception) {
            }
        }
        return null
    }

    private fun iso(date: Date): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(date)
    }
}
