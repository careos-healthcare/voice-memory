package com.voicememory.mobile.integration

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class BoundedStreamsTest {
    @Test
    fun copyAcceptsPayloadAtLimit() {
        val output = ByteArrayOutputStream()

        val count = BoundedStreams.copy(
            ByteArrayInputStream(byteArrayOf(1, 2, 3, 4)),
            output,
            4,
        )

        assertEquals(4, count)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), output.toByteArray())
    }

    @Test
    fun copyRejectsPayloadBeyondLimit() {
        assertThrows(PayloadTooLargeException::class.java) {
            BoundedStreams.copy(
                ByteArrayInputStream(ByteArray(9)),
                ByteArrayOutputStream(),
                8,
            )
        }
    }

    @Test
    fun readWindowReturnsOnlyRequestedChunk() {
        val result = BoundedStreams.readWindow(
            ByteArrayInputStream("0123456789".toByteArray()),
            offset = 3,
            maximumBytes = 4,
        )

        assertEquals("3456", result.toString(Charsets.UTF_8))
    }

    @Test
    fun utf8TruncationNeverSplitsCodePoint() {
        assertEquals("ab", ShareHandoffStore.truncateUtf8("ab\u20accd", 4))
        assertEquals("ab\u20ac", ShareHandoffStore.truncateUtf8("ab\u20accd", 5))
    }

    @Test
    fun exactHttpAndHttpsSharesAreNormalizedAsUrls() {
        assertEquals(
            ShareHandoffStore.SharedText("https://example.com/path?q=1", "url"),
            ShareHandoffStore.normalizeSharedText("  https://example.com/path?q=1  "),
        )
        assertEquals(
            ShareHandoffStore.SharedText("HTTP://example.com", "url"),
            ShareHandoffStore.normalizeSharedText("HTTP://example.com"),
        )
    }

    @Test
    fun ordinaryTextAndEmbeddedUrlsRemainText() {
        assertEquals(
            ShareHandoffStore.SharedText("Remember https://example.com later", "text"),
            ShareHandoffStore.normalizeSharedText("Remember https://example.com later"),
        )
        assertEquals(
            ShareHandoffStore.SharedText("ftp://example.com/file", "text"),
            ShareHandoffStore.normalizeSharedText("ftp://example.com/file"),
        )
    }
}
