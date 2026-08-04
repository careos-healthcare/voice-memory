package com.voicememory.mobile.integration

import java.io.ByteArrayInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ShareHandoffParsingTest {
    @Test
    fun `classifies only absolute http links as urls`() {
        assertEquals(
            "url",
            ShareHandoffStore.normalizeSharedText(" https://example.com/path ").kind,
        )
        assertEquals(
            "text",
            ShareHandoffStore.normalizeSharedText("example.com/path").kind,
        )
        assertEquals(
            "text",
            ShareHandoffStore.normalizeSharedText("javascript:alert(1)").kind,
        )
    }

    @Test
    fun `UTF-8 truncation never splits a multibyte scalar`() {
        assertEquals("ab", ShareHandoffStore.truncateUtf8("ab🙂", 5))
        assertEquals("ab🙂", ShareHandoffStore.truncateUtf8("ab🙂", 6))
    }

    @Test
    fun `authenticated window consumes and validates the complete stream`() {
        val bytes = ByteArray(1024) { (it % 251).toByte() }
        val window = BoundedStreams.readAuthenticatedWindow(
            ByteArrayInputStream(bytes),
            bytes.size.toLong(),
            100,
            64,
        )
        assertArrayEquals(bytes.copyOfRange(100, 164), window)
    }

    @Test
    fun `authenticated window rejects truncated plaintext`() {
        assertThrows(IllegalArgumentException::class.java) {
            BoundedStreams.readAuthenticatedWindow(
                ByteArrayInputStream(byteArrayOf(1, 2)),
                3,
                0,
                3,
            )
        }
    }
}
