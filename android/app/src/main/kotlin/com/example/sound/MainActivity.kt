package com.example.sound

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.AudioFormat
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity: FlutterActivity() {
    private val audioInputChannel = "de.onenightproductions.sketchord/audio_input"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioInputChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "decodeToWav") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("audioPath")
                if (path.isNullOrEmpty()) {
                    result.error("invalid_audio", "A source audio path is required.", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(decodeToWav(path))
                } catch (exception: Exception) {
                    result.error("decode_failed", exception.message, null)
                }
            }
    }

    private fun decodeToWav(sourcePath: String): String {
        val extractor = MediaExtractor()
        extractor.setDataSource(sourcePath)
        var track = -1
        var inputFormat: MediaFormat? = null
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            if (format.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                track = index
                inputFormat = format
                break
            }
        }
        require(track >= 0 && inputFormat != null) { "No audio track was found." }
        extractor.selectTrack(track)
        val mime = inputFormat.getString(MediaFormat.KEY_MIME)!!
        val decoder = MediaCodec.createDecoderByType(mime)
        decoder.configure(inputFormat, null, null, 0)
        decoder.start()

        val destination = File(cacheDir, "transcription-pcm").apply { mkdirs() }
        val output = File(destination, "${File(sourcePath).nameWithoutExtension}_${File(sourcePath).lastModified()}.wav")
        var sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var dataBytes = 0L
        val info = MediaCodec.BufferInfo()
        var inputEnded = false
        var outputEnded = false

        FileOutputStream(output).use { stream ->
            stream.write(ByteArray(44)) // Filled in after decoder reveals the output format.
            while (!outputEnded) {
                if (!inputEnded) {
                    val inputIndex = decoder.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val input = decoder.getInputBuffer(inputIndex)!!
                        val size = extractor.readSampleData(input, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputEnded = true
                        } else {
                            decoder.queueInputBuffer(inputIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                when (val outputIndex = decoder.dequeueOutputBuffer(info, 10_000)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val format = decoder.outputFormat
                        sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        val encoding = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                            format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            format.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        } else AudioFormat.ENCODING_PCM_16BIT
                        require(encoding == AudioFormat.ENCODING_PCM_16BIT) {
                            "The device returned unsupported decoded PCM."
                        }
                    }
                    in 0..Int.MAX_VALUE -> {
                        val buffer = decoder.getOutputBuffer(outputIndex)!!
                        if (info.size > 0) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            val bytes = ByteArray(info.size)
                            buffer.get(bytes)
                            stream.write(bytes)
                            dataBytes += bytes.size
                        }
                        decoder.releaseOutputBuffer(outputIndex, false)
                        outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    }
                }
            }
        }
        decoder.stop()
        decoder.release()
        extractor.release()
        require(dataBytes > 0) { "The audio clip contained no decoded samples." }
        writePcmWaveHeader(output, sampleRate, channels, dataBytes)
        return output.absolutePath
    }

    private fun writePcmWaveHeader(file: File, sampleRate: Int, channels: Int, dataBytes: Long) {
        RandomAccessFile(file, "rw").use { output ->
            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            header.put("RIFF".toByteArray())
            header.putInt((36 + dataBytes).toInt())
            header.put("WAVEfmt ".toByteArray())
            header.putInt(16)
            header.putShort(1.toShort())
            header.putShort(channels.toShort())
            header.putInt(sampleRate)
            header.putInt(sampleRate * channels * 2)
            header.putShort((channels * 2).toShort())
            header.putShort(16)
            header.put("data".toByteArray())
            header.putInt(dataBytes.toInt())
            output.seek(0)
            output.write(header.array())
        }
    }
}
