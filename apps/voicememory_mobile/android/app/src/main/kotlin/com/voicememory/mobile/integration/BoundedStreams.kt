package com.voicememory.mobile.integration

import java.io.InputStream
import java.io.OutputStream

internal object BoundedStreams {
    fun copy(input: InputStream, output: OutputStream, maximumBytes: Long): Long {
        require(maximumBytes >= 0)
        val buffer = ByteArray(32 * 1024)
        var total = 0L
        while (true) {
            val allowed = minOf(buffer.size.toLong(), maximumBytes - total + 1).toInt()
            val read = input.read(buffer, 0, allowed)
            if (read < 0) return total
            total += read
            if (total > maximumBytes) throw PayloadTooLargeException(maximumBytes)
            output.write(buffer, 0, read)
        }
    }

    fun readWindow(
        input: InputStream,
        offset: Long,
        maximumBytes: Int,
    ): ByteArray {
        require(offset >= 0 && maximumBytes in 1..MAX_CHANNEL_CHUNK_BYTES)
        var remaining = offset
        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped > 0) {
                remaining -= skipped
            } else if (input.read() < 0) {
                return ByteArray(0)
            } else {
                remaining--
            }
        }
        val output = java.io.ByteArrayOutputStream(maximumBytes)
        val buffer = ByteArray(minOf(32 * 1024, maximumBytes))
        var left = maximumBytes
        while (left > 0) {
            val read = input.read(buffer, 0, minOf(buffer.size, left))
            if (read < 0) break
            output.write(buffer, 0, read)
            left -= read
        }
        return output.toByteArray()
    }

    /**
     * Reads the complete AEAD plaintext before returning a window.
     *
     * AES-GCM authentication is only verified when the cipher stream reaches
     * EOF. Returning an early window from a CipherInputStream would expose
     * unauthenticated plaintext to Flutter for every non-final chunk.
     */
    fun readAuthenticatedWindow(
        input: InputStream,
        totalBytes: Long,
        offset: Long,
        maximumBytes: Int,
    ): ByteArray {
        require(totalBytes in 0..MAX_AUTHENTICATED_ITEM_BYTES)
        require(offset >= 0 && maximumBytes in 1..MAX_CHANNEL_CHUNK_BYTES)
        val allBytes = ByteArray(totalBytes.toInt())
        try {
            var filled = 0
            while (filled < allBytes.size) {
                val read = input.read(allBytes, filled, allBytes.size - filled)
                require(read >= 0) { "Unexpected decrypted item size" }
                filled += read
            }
            // Force CipherInputStream through doFinal so the GCM tag is
            // authenticated before any bytes leave this method.
            require(input.read() < 0) { "Decrypted item exceeds its manifest size" }
            if (offset >= allBytes.size) return ByteArray(0)
            val start = offset.toInt()
            return allBytes.copyOfRange(start, minOf(allBytes.size, start + maximumBytes))
        } finally {
            allBytes.fill(0)
        }
    }

    const val MAX_AUTHENTICATED_ITEM_BYTES = 20L * 1024 * 1024
    const val MAX_CHANNEL_CHUNK_BYTES = MAX_AUTHENTICATED_ITEM_BYTES.toInt()
}

internal class PayloadTooLargeException(limit: Long) :
    IllegalArgumentException("Payload exceeds the $limit byte limit")
