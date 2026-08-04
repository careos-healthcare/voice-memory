package com.voicememory.mobile.audio

import android.media.MediaRecorder
import java.io.File
import java.io.RandomAccessFile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeAudioHelpersTest {
    @Test
    fun processingControlParsingDefaultsUnknownValues() {
        assertEquals(ProcessingControl.ENABLED, ProcessingControl.from("enabled"))
        assertEquals(ProcessingControl.DISABLED, ProcessingControl.from("disabled"))
        assertEquals(ProcessingControl.PLATFORM_DEFAULT, ProcessingControl.from(null))
        assertEquals(ProcessingControl.PLATFORM_DEFAULT, ProcessingControl.from("future-value"))
    }

    @Test
    fun rateCandidatesClampAndRetainFallbacks() {
        assertEquals(
            listOf(8000, 16000, 44100, 48000),
            NativeAudioHelpers.rateCandidates(-1),
        )
    }

    @Test
    fun sourceCandidatesPreferModeAndAlwaysFallBackToMic() {
        assertEquals(
            listOf(MediaRecorder.AudioSource.UNPROCESSED, MediaRecorder.AudioSource.MIC),
            NativeAudioHelpers.sourceCandidates("measurement", supportsUnprocessed = true),
        )
        assertEquals(
            listOf(MediaRecorder.AudioSource.VOICE_RECOGNITION, MediaRecorder.AudioSource.MIC),
            NativeAudioHelpers.sourceCandidates("spokenAudio", supportsUnprocessed = false),
        )
    }

    @Test
    fun bufferSizeHonorsDurationAndPlatformMinimum() {
        assertEquals(640, NativeAudioHelpers.calculateBufferBytes(16000, 20.0, 128))
        assertEquals(2048, NativeAudioHelpers.calculateBufferBytes(16000, 20.0, 2048))
    }

    @Test
    fun rawAndMeasurementModesDisableAllFilters() {
        val requested = ProcessingRequest(
            acousticEchoCancellation = ProcessingControl.ENABLED,
            noiseSuppression = ProcessingControl.PLATFORM_DEFAULT,
            automaticGainControl = ProcessingControl.ENABLED,
        )

        for (mode in listOf("raw", "measurement")) {
            val applied = NativeAudioHelpers.processingPolicy(mode, requested)
            assertEquals(ProcessingControl.DISABLED, applied.acousticEchoCancellation)
            assertEquals(ProcessingControl.DISABLED, applied.noiseSuppression)
            assertEquals(ProcessingControl.DISABLED, applied.automaticGainControl)
        }
    }

    @Test
    fun spokenAudioPreservesRequestedFilterPolicy() {
        val requested = ProcessingRequest(
            acousticEchoCancellation = ProcessingControl.ENABLED,
            noiseSuppression = ProcessingControl.DISABLED,
            automaticGainControl = ProcessingControl.PLATFORM_DEFAULT,
        )

        assertEquals(
            requested,
            NativeAudioHelpers.processingPolicy("spokenAudio", requested),
        )
    }

    @Test
    fun timeoutCleanupReleasesAndClearsStateBeforeDiscardingOutput() {
        val events = mutableListOf<String>()

        val failure = RecorderStopCleanup.run(
            successful = false,
            releaseResources = { events += "release" },
            clearWorker = { events += "clearWorker" },
            clearActive = { events += "clearActive" },
            discardIncompleteOutput = { events += "discard" },
        )

        assertEquals(
            listOf("release", "clearWorker", "clearActive", "discard"),
            events,
        )
        assertEquals(null, failure)
    }

    @Test
    fun timeoutCleanupAttemptsEveryStepAndReturnsTheFirstFailure() {
        val events = mutableListOf<String>()
        val releaseFailure = IllegalStateException("release failed")

        val failure = RecorderStopCleanup.run(
            successful = false,
            releaseResources = {
                events += "release"
                throw releaseFailure
            },
            clearWorker = { events += "clearWorker" },
            clearActive = { events += "clearActive" },
            discardIncompleteOutput = { events += "discard" },
        )

        assertSame(releaseFailure, failure)
        assertEquals(
            listOf("release", "clearWorker", "clearActive", "discard"),
            events,
        )
    }

    @Test
    fun successfulCleanupKeepsFinalizedOutput() {
        var discarded = false

        val failure = RecorderStopCleanup.run(
            successful = true,
            releaseResources = {},
            clearWorker = {},
            clearActive = {},
            discardIncompleteOutput = { discarded = true },
        )

        assertEquals(null, failure)
        assertFalse(discarded)
    }

    @Test
    fun processingReleaseActionRunsExactlyOnce() {
        var releases = 0
        val release = OnceAction { releases++ }

        release.run()
        release.run()

        assertEquals(1, releases)
    }

    @Test
    fun wavHeaderContainsPcmShapeAndDataLength() {
        val file = File.createTempFile("native-audio", ".wav")
        try {
            RandomAccessFile(file, "rw").use { output ->
                output.write(ByteArray(NativeAudioHelpers.WAV_HEADER_BYTES))
                NativeAudioHelpers.writeWavHeader(
                    output,
                    dataBytes = 32000,
                    sampleRate = 16000,
                    channels = 1,
                    bitDepth = 16,
                )
            }
            val bytes = file.readBytes()
            assertEquals("RIFF", bytes.copyOfRange(0, 4).decodeToString())
            assertEquals("WAVE", bytes.copyOfRange(8, 12).decodeToString())
            assertEquals("data", bytes.copyOfRange(36, 40).decodeToString())
            assertEquals(32000, littleEndianInt(bytes, 40))
            assertTrue(bytes.size >= NativeAudioHelpers.WAV_HEADER_BYTES)
        } finally {
            file.delete()
        }
    }

    private fun littleEndianInt(bytes: ByteArray, offset: Int): Int =
        (bytes[offset].toInt() and 0xff) or
            ((bytes[offset + 1].toInt() and 0xff) shl 8) or
            ((bytes[offset + 2].toInt() and 0xff) shl 16) or
            ((bytes[offset + 3].toInt() and 0xff) shl 24)
}
