package com.voicememory.mobile

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

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

        return mapOf(
            "path" to outputFile.absolutePath,
            "compressed" to true,
            "bytes" to outputFile.length(),
        )
    }
}

object CaptureAudioCompressorHandler {
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
            else -> result.notImplemented()
        }
    }
}
