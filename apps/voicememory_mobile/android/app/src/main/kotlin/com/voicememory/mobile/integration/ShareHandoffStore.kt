package com.voicememory.mobile.integration

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.URI
import java.util.UUID

internal object ShareHandoffStore {
    private const val MAX_ITEMS = 12
    private const val MAX_ITEM_BYTES = 20L * 1024 * 1024
    private const val MAX_TEXT_BYTES = 100_000
    private const val MAX_NAME_BYTES = 512
    private const val MANIFEST_FILE = "manifest.enc"
    private const val MANIFEST_AAD_PREFIX = "share-manifest:"
    private const val ITEM_AAD_PREFIX = "share-item:"

    fun accepts(intent: Intent?): Boolean =
        intent?.action == Intent.ACTION_SEND || intent?.action == Intent.ACTION_SEND_MULTIPLE

    fun ingest(context: Context, intent: Intent): String? {
        if (!accepts(intent)) return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?.let { truncateUtf8(it, MAX_TEXT_BYTES) }
            ?.takeIf { it.isNotBlank() }
            ?.let(::normalizeSharedText)
        val uris = collectUris(intent).take(MAX_ITEMS)
        if (text == null && uris.isEmpty()) return null

        return SecureNativeStorage.locked(context) {
            val handoffId = UUID.randomUUID().toString()
            val directory = File(root(context), handoffId).apply { mkdirs() }
            val items = JSONArray()
            try {
                if (text != null) {
                    val itemIndex = items.length()
                    val dataFile = File(directory, "$itemIndex.enc")
                    val bytes = text.value.toByteArray(Charsets.UTF_8)
                    SecureNativeStorage.writeEncryptedAtomic(
                        dataFile,
                        itemAad(handoffId, itemIndex),
                    ) { it.write(bytes) }
                    items.put(
                        JSONObject()
                            .put("kind", text.kind)
                            .put("mimeType", intent.type?.take(128) ?: "text/plain")
                            .put("name", JSONObject.NULL)
                            .put("size", bytes.size),
                    )
                }
                for (uri in uris.take(MAX_ITEMS - items.length())) {
                    val itemIndex = items.length()
                    val metadata = queryMetadata(context, uri)
                    if (metadata.size != null && metadata.size > MAX_ITEM_BYTES) continue
                    val dataFile = File(directory, "$itemIndex.enc")
                    val bytesWritten = context.contentResolver.openInputStream(uri)?.use { input ->
                        var count = 0L
                        SecureNativeStorage.writeEncryptedAtomic(
                            dataFile,
                            itemAad(handoffId, itemIndex),
                        ) { encrypted ->
                            count = BoundedStreams.copy(input, encrypted, MAX_ITEM_BYTES)
                        }
                        count
                    } ?: continue
                    if (bytesWritten <= 0) {
                        dataFile.delete()
                        continue
                    }
                    items.put(
                        JSONObject()
                            .put(
                                "kind",
                                if (metadata.mimeType.startsWith("image/")) "image" else "file",
                            )
                            .put("mimeType", metadata.mimeType)
                            .put("name", metadata.name ?: JSONObject.NULL)
                            .put("size", bytesWritten),
                    )
                }
                if (items.length() == 0) {
                    directory.deleteRecursively()
                    return@locked null
                }
                val manifest = JSONObject()
                    .put("id", handoffId)
                    .put("createdAt", System.currentTimeMillis())
                    .put("items", items)
                SecureNativeStorage.writeEncryptedAtomic(
                    File(directory, MANIFEST_FILE),
                    "$MANIFEST_AAD_PREFIX$handoffId",
                ) { it.write(manifest.toString().toByteArray(Charsets.UTF_8)) }
                handoffId
            } catch (error: Throwable) {
                directory.deleteRecursively()
                throw error
            }
        }
    }

    fun list(context: Context): List<Map<String, Any?>> = SecureNativeStorage.locked(context) {
        root(context).listFiles()
            .orEmpty()
            .asSequence()
            .filter { it.isDirectory && UUID_PATTERN.matches(it.name) }
            .mapNotNull { directory -> readManifest(directory)?.let(::manifestMap) }
            .sortedBy { (it["createdAt"] as? Number)?.toLong() ?: 0L }
            .toList()
    }

    fun readItem(
        context: Context,
        handoffId: String,
        itemIndex: Int,
        offset: Long,
        maximumBytes: Int,
    ): ByteArray = SecureNativeStorage.locked(context) {
        requireValidId(handoffId)
        require(itemIndex in 0 until MAX_ITEMS)
        val directory = File(root(context), handoffId)
        val manifest = readManifest(directory) ?: error("Unknown share handoff")
        val items = manifest.getJSONArray("items")
        require(itemIndex < items.length()) { "Unknown share item" }
        val expectedSize = items.getJSONObject(itemIndex).getLong("size")
        require(expectedSize in 0..MAX_ITEM_BYTES) { "Invalid share item size" }
        SecureNativeStorage.readEncrypted(
            File(directory, "$itemIndex.enc"),
            itemAad(handoffId, itemIndex),
        ).use {
            BoundedStreams.readAuthenticatedWindow(
                it,
                expectedSize,
                offset,
                maximumBytes,
            )
        }
    }

    fun delete(context: Context, handoffId: String): Boolean = SecureNativeStorage.locked(context) {
        requireValidId(handoffId)
        val directory = File(root(context), handoffId)
        directory.exists() && directory.deleteRecursively()
    }

    private fun collectUris(intent: Intent): List<Uri> {
        val values = LinkedHashSet<Uri>()
        intent.clipData?.let { clip ->
            for (index in 0 until minOf(clip.itemCount, MAX_ITEMS)) {
                clip.getItemAt(index).uri?.let(values::add)
            }
        }
        @Suppress("DEPRECATION")
        when (intent.action) {
            Intent.ACTION_SEND -> (intent.getParcelableExtra<android.os.Parcelable>(Intent.EXTRA_STREAM) as? Uri)
                ?.let(values::add)
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<android.os.Parcelable>(Intent.EXTRA_STREAM)
                    ?.mapNotNull { it as? Uri }
                    ?.forEach(values::add)
        }
        return values.toList()
    }

    private fun queryMetadata(context: Context, uri: Uri): ShareMetadata {
        var name: String? = null
        var size: Long? = null
        context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                name = cursor.safeString(OpenableColumns.DISPLAY_NAME)
                    ?.let { truncateUtf8(it, MAX_NAME_BYTES) }
                size = cursor.safeLong(OpenableColumns.SIZE)
            }
        }
        val mime = context.contentResolver.getType(uri)
            ?.take(128)
            ?.takeIf(MIME_PATTERN::matches)
            ?: "application/octet-stream"
        return ShareMetadata(name, size, mime)
    }

    private fun readManifest(directory: File): JSONObject? {
        val file = File(directory, MANIFEST_FILE)
        if (!file.isFile) return null
        return runCatching {
            SecureNativeStorage.readEncrypted(
                file,
                "$MANIFEST_AAD_PREFIX${directory.name}",
            ).bufferedReader(Charsets.UTF_8).use { JSONObject(it.readText()) }
        }.getOrNull()
    }

    private fun manifestMap(manifest: JSONObject): Map<String, Any?> {
        val items = manifest.getJSONArray("items")
        return mapOf(
            "id" to manifest.getString("id"),
            "createdAt" to manifest.getLong("createdAt"),
            "items" to List(items.length()) { index ->
                val item = items.getJSONObject(index)
                mapOf(
                    "index" to index,
                    "kind" to item.getString("kind"),
                    "mimeType" to item.getString("mimeType"),
                    "name" to item.optString("name").takeIf { !item.isNull("name") },
                    "size" to item.getLong("size"),
                )
            },
        )
    }

    private fun Cursor.safeString(column: String): String? =
        getColumnIndex(column).takeIf { it >= 0 && !isNull(it) }?.let(::getString)

    private fun Cursor.safeLong(column: String): Long? =
        getColumnIndex(column).takeIf { it >= 0 && !isNull(it) }?.let(::getLong)

    private fun root(context: Context) =
        File(context.noBackupFilesDir, "native_os/shares").apply { mkdirs() }

    private fun requireValidId(id: String) {
        require(UUID_PATTERN.matches(id)) { "Invalid share handoff ID" }
    }

    private fun itemAad(id: String, index: Int) = "$ITEM_AAD_PREFIX$id:$index"

    internal fun truncateUtf8(value: String, maximumBytes: Int): String {
        val bytes = value.toByteArray(Charsets.UTF_8)
        if (bytes.size <= maximumBytes) return value
        var end = maximumBytes
        while (end > 0 && (bytes[end].toInt() and 0xc0) == 0x80) end--
        return bytes.copyOf(end).toString(Charsets.UTF_8)
    }

    internal fun normalizeSharedText(value: String): SharedText {
        val trimmed = value.trim()
        val isHttpUrl = runCatching {
            val uri = URI(trimmed)
            (uri.scheme.equals("http", ignoreCase = true) ||
                uri.scheme.equals("https", ignoreCase = true)) &&
                !uri.host.isNullOrBlank()
        }.getOrDefault(false)
        return if (isHttpUrl) SharedText(trimmed, "url") else SharedText(value, "text")
    }

    internal data class SharedText(
        val value: String,
        val kind: String,
    )

    private data class ShareMetadata(
        val name: String?,
        val size: Long?,
        val mimeType: String,
    )

    private val UUID_PATTERN =
        Regex("[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}")
    private val MIME_PATTERN = Regex("[\\w.+-]{1,64}/[\\w.+-]{1,64}")
}
