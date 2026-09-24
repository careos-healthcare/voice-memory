package com.voicememory.mobile

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

object CaptureAudioCompressor {
    fun compress(
        inputPath: String,
        outputPath: String,
        sampleRateHz: Int,
        bitRateBps: Int,
        channelCount: Int,
    ): Map<String, Any?> {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            throw IllegalStateException("input_missing")
        }

        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) {
            outputFile.delete()
        }

        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)
        var audioTrackIndex = -1
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                audioTrackIndex = index
                break
            }
        }
        if (audioTrackIndex < 0) {
            extractor.release()
            throw IllegalStateException("no_audio_track")
        }
        extractor.selectTrack(audioTrackIndex)

        val outputFormat = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            sampleRateHz,
            channelCount,
        ).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, bitRateBps)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        encoder.configure(outputFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var muxerTrack = -1
        var muxerStarted = false

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false

        while (!outputDone) {
            if (!inputDone) {
                val inputIndex = encoder.dequeueInputBuffer(10_000)
                if (inputIndex >= 0) {
                    val inputBuffer = encoder.getInputBuffer(inputIndex) ?: continue
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)
                    if (sampleSize < 0) {
                        encoder.queueInputBuffer(
                            inputIndex,
                            0,
                            0,
                            0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                        )
                        inputDone = true
                    } else {
                        val presentationTimeUs = extractor.sampleTime
                        encoder.queueInputBuffer(
                            inputIndex,
                            0,
                            sampleSize,
                            presentationTimeUs,
                            0,
                        )
                        extractor.advance()
                    }
                }
            }

            val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxerStarted) {
                        throw IllegalStateException("format_changed_twice")
                    }
                    muxerTrack = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                outputIndex >= 0 -> {
                    val encodedBuffer = encoder.getOutputBuffer(outputIndex) ?: continue
                    if (bufferInfo.size > 0 && muxerStarted) {
                        encodedBuffer.position(bufferInfo.offset)
                        encodedBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(muxerTrack, encodedBuffer, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                }
            }
        }

        extractor.release()
        encoder.stop()
        encoder.release()
        if (muxerStarted) {
            muxer.stop()
        }
        muxer.release()
        requirePlayable(outputFile, ogg = false)

        return mapOf(
            "path" to outputFile.absolutePath,
            "compressed" to true,
            "bytes" to outputFile.length(),
            "codec" to "aac",
        )
    }

    fun compressAfterTranscription(inputPath: String, outputPath: String): Map<String, Any?> {
        val payload = try {
            if (android.os.Build.VERSION.SDK_INT >= 29) {
                compressOpus(inputPath, outputPath)
            } else {
                compressAac(inputPath, outputPath)
            }
        } catch (error: Exception) {
            File(sibling(outputPath, "ogg")).delete()
            compressAac(inputPath, outputPath)
        }
        val storedPath = payload["path"] as? String ?: outputPath
        requirePlayable(File(storedPath), ogg = storedPath.endsWith(".ogg"))
        val discarded = discardRawSource(inputPath, storedPath)
        return payload + mapOf("discardedRaw" to discarded)
    }

    private fun compressAac(inputPath: String, outputPath: String): Map<String, Any?> {
        val m4a = sibling(outputPath, "m4a")
        return try {
            compress(
                inputPath = inputPath,
                outputPath = m4a,
                sampleRateHz = 16000,
                bitRateBps = 24000,
                channelCount = 1,
            )
        } catch (error: Exception) {
            File(m4a).delete()
            encodePcm(
                inputPath = inputPath,
                outputPath = m4a,
                mime = MediaFormat.MIMETYPE_AUDIO_AAC,
                muxerFormat = MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
                bitRate = 24000,
                codecName = "aac",
            )
        }
    }

    private fun compressOpus(inputPath: String, outputPath: String): Map<String, Any?> {
        val oggPath = sibling(outputPath, "ogg")
        try {
            val extracted = encodeOpusContainer(inputPath, oggPath)
            requirePlayable(File(oggPath), ogg = true)
            return extracted
        } catch (error: Exception) {
            File(oggPath).delete()
        }
        val encoded = encodePcm(
            inputPath = inputPath,
            outputPath = oggPath,
            mime = MediaFormat.MIMETYPE_AUDIO_OPUS,
            muxerFormat = MediaMuxer.OutputFormat.MUXER_OUTPUT_OGG,
            bitRate = 12000,
            codecName = "opus",
        )
        requirePlayable(File(oggPath), ogg = true)
        return encoded
    }

    private fun encodeOpusContainer(inputPath: String, oggPath: String): Map<String, Any?> {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) throw IllegalStateException("input_missing")
        val outputFile = File(oggPath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) outputFile.delete()

        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)
        var audioTrackIndex = -1
        for (index in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                audioTrackIndex = index
                break
            }
        }
        if (audioTrackIndex < 0) {
            extractor.release()
            throw IllegalStateException("no_audio_track")
        }
        extractor.selectTrack(audioTrackIndex)

        val outputFormat = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_OPUS,
            16000,
            1,
        ).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 12000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_OPUS)
        encoder.configure(outputFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()
        val muxer = MediaMuxer(oggPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_OGG)
        var muxerTrack = -1
        var muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        try {
            while (!outputDone) {
                if (!inputDone) {
                    val inputIndex = encoder.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = encoder.getInputBuffer(inputIndex) ?: continue
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            encoder.queueInputBuffer(
                                inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            encoder.queueInputBuffer(
                                inputIndex, 0, sampleSize, extractor.sampleTime, 0,
                            )
                            extractor.advance()
                        }
                    }
                }
                val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        muxerTrack = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outputIndex >= 0 -> {
                        val encoded = encoder.getOutputBuffer(outputIndex)
                        if (encoded != null && bufferInfo.size > 0 && muxerStarted) {
                            encoded.position(bufferInfo.offset)
                            encoded.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(muxerTrack, encoded, bufferInfo)
                        }
                        encoder.releaseOutputBuffer(outputIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
        } finally {
            extractor.release()
            encoder.stop()
            encoder.release()
            if (muxerStarted) muxer.stop()
            muxer.release()
        }
        requirePlayable(outputFile, ogg = true)
        return mapOf(
            "path" to outputFile.absolutePath,
            "compressed" to true,
            "bytes" to outputFile.length(),
            "codec" to "opus",
        )
    }

    private fun encodePcm(
        inputPath: String,
        outputPath: String,
        mime: String,
        muxerFormat: Int,
        bitRate: Int,
        codecName: String,
    ): Map<String, Any?> {
        val pcm = readPcm(File(inputPath))
        if (pcm.pcm.isEmpty()) throw IllegalStateException("pcm_empty")
        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) outputFile.delete()

        val outputFormat = MediaFormat.createAudioFormat(mime, pcm.sampleRate, pcm.channels).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            if (mime == MediaFormat.MIMETYPE_AUDIO_AAC) {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            }
        }
        val encoder = MediaCodec.createEncoderByType(mime)
        encoder.configure(outputFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()
        val muxer = MediaMuxer(outputPath, muxerFormat)
        var muxerTrack = -1
        var muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        var offset = 0
        val bytesPerSecond = (pcm.sampleRate * pcm.channels * 2).coerceAtLeast(1)
        val frameBytes = (bytesPerSecond / 50).coerceAtLeast(2)
        var presentationUs = 0L
        try {
            while (!outputDone) {
                if (!inputDone) {
                    val inputIndex = encoder.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = encoder.getInputBuffer(inputIndex) ?: continue
                        inputBuffer.clear()
                        if (offset >= pcm.pcm.size) {
                            encoder.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                presentationUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            val count = minOf(frameBytes, pcm.pcm.size - offset, inputBuffer.remaining())
                            inputBuffer.put(pcm.pcm, offset, count)
                            encoder.queueInputBuffer(inputIndex, 0, count, presentationUs, 0)
                            presentationUs += count.toLong() * 1_000_000L / bytesPerSecond
                            offset += count
                        }
                    }
                }
                val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        muxerTrack = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outputIndex >= 0 -> {
                        val encoded = encoder.getOutputBuffer(outputIndex)
                        if (encoded != null && bufferInfo.size > 0 && muxerStarted) {
                            encoded.position(bufferInfo.offset)
                            encoded.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(muxerTrack, encoded, bufferInfo)
                        }
                        encoder.releaseOutputBuffer(outputIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
        } finally {
            encoder.stop()
            encoder.release()
            if (muxerStarted) muxer.stop()
            muxer.release()
        }
        requirePlayable(outputFile, ogg = outputPath.endsWith(".ogg"))
        return mapOf(
            "path" to outputFile.absolutePath,
            "compressed" to true,
            "bytes" to outputFile.length(),
            "codec" to codecName,
        )
    }

    private data class PcmAudio(val pcm: ByteArray, val sampleRate: Int, val channels: Int)

    private fun readPcm(file: File): PcmAudio {
        if (!file.exists()) throw IllegalStateException("input_missing")
        val bytes = file.readBytes()
        if (bytes.size >= 12 && String(bytes, 0, 4, Charsets.US_ASCII) == "RIFF") {
            return parseWav(bytes)
        }
        return PcmAudio(bytes, 16000, 1)
    }

    private fun parseWav(bytes: ByteArray): PcmAudio {
        var offset = 12
        var rate = 16000
        var channels = 1
        var data: ByteArray? = null
        while (offset + 8 <= bytes.size) {
            val id = String(bytes, offset, 4, Charsets.US_ASCII)
            val size = ByteBuffer.wrap(bytes, offset + 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
            if (size < 0) break
            val start = offset + 8
            if (start > bytes.size) break
            if (id == "fmt " && size >= 16 && start + 16 <= bytes.size) {
                val header = ByteBuffer.wrap(bytes, start, 16).order(ByteOrder.LITTLE_ENDIAN)
                header.short
                channels = header.short.toInt().coerceIn(1, 2)
                rate = header.int.coerceAtLeast(8000)
            } else if (id == "data") {
                val end = (start + size).coerceAtMost(bytes.size)
                data = bytes.copyOfRange(start, end)
            }
            val padded = size + (size and 1)
            offset = start + padded
        }
        return PcmAudio(data ?: bytes, rate, channels)
    }

    private fun sibling(outputPath: String, extension: String): String {
        val file = File(outputPath)
        val base = file.name.substringBeforeLast('.', file.name)
        return File(file.parentFile, "$base.$extension").path
    }

    private fun requirePlayable(file: File, ogg: Boolean) {
        if (!file.exists() || file.length() < 16L) {
            throw IllegalStateException("output_invalid")
        }
        val head = ByteArray(12)
        file.inputStream().use { stream ->
            if (stream.read(head) < 12) throw IllegalStateException("output_invalid")
        }
        if (ogg) {
            val magic = String(head, 0, 4, Charsets.US_ASCII)
            if (magic != "OggS") throw IllegalStateException("output_invalid")
            return
        }
        val brand = String(head, 4, 4, Charsets.US_ASCII)
        if (brand != "ftyp") throw IllegalStateException("output_invalid")
    }

    private fun discardRawSource(inputPath: String, outputPath: String): Boolean {
        val input = File(inputPath)
        val output = File(outputPath)
        val ext = input.extension.lowercase()
        val raw = ext == "wav" || ext == "wave" || ext == "pcm"
        if (!raw || input.absolutePath == output.absolutePath || !output.exists()) return false
        return input.delete()
    }
}

object CaptureAudioCompressorHandler {
    const val channelName = "com.archiveme/audio_compression"

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger) {
        io.flutter.plugin.common.MethodChannel(messenger, channelName)
            .setMethodCallHandler(::handle)
    }

    fun handle(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        when (call.method) {
            "compressForUpload" -> {
                val args = call.arguments as? Map<*, *>
                val inputPath = args?.get("inputPath") as? String
                val outputPath = args?.get("outputPath") as? String
                if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                    result.error("invalid_args", "Expected input/output paths", null)
                    return
                }
                val sampleRateHz = (args["sampleRateHz"] as? Number)?.toInt() ?: 16000
                val bitRateBps = (args["bitRateBps"] as? Number)?.toInt() ?: 32000
                val channelCount = (args["channelCount"] as? Number)?.toInt() ?: 1
                try {
                    val payload = CaptureAudioCompressor.compress(
                        inputPath = inputPath,
                        outputPath = outputPath,
                        sampleRateHz = sampleRateHz,
                        bitRateBps = bitRateBps,
                        channelCount = channelCount,
                    )
                    result.success(payload)
                } catch (error: Exception) {
                    result.error("compress_failed", error.message, null)
                }
            }
            "compressAfterTranscription" -> {
                val args = call.arguments as? Map<*, *>
                val inputPath = args?.get("inputPath") as? String
                val outputPath = args?.get("outputPath") as? String
                if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                    result.error("invalid_args", "Expected input/output paths", null)
                    return
                }
                try {
                    result.success(
                        CaptureAudioCompressor.compressAfterTranscription(inputPath, outputPath),
                    )
                } catch (error: Exception) {
                    result.error("compress_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
