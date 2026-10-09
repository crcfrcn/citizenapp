package com.crcfrcn.citizenapp

import android.content.Context
import android.os.Process
import android.os.StatFs
import android.system.Os
import android.system.OsConstants
import android.system.ErrnoException
import java.io.File
import java.util.UUID
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** 公民广场媒体原生入口；通道字段统一使用 snake_case。 */
class SquareMediaChannel(
    messenger: BinaryMessenger,
    context: Context,
) {
    private val transcoder = SquareVideoTranscoder(context.applicationContext)
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val storageContext = context.applicationContext
    private var playbackInitializationFailed = false

    init {
        synchronized(playbackFiles) {
            try {
                playbackDirectory()
            } catch (_: Exception) {
                playbackInitializationFailed = true
            }
        }
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        transcoder.cancel()
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(transcoder.capabilities())
            "transcode_video" -> {
                try {
                    transcoder.transcode(SquareVideoRequest.from(call), result)
                } catch (error: Exception) {
                    result.error("square_media_invalid", error.message, null)
                }
            }
            "prepare_playback_file", "verify_playback_file", "delete_playback_file" -> {
                try {
                    synchronized(playbackFiles) {
                        require(!playbackInitializationFailed)
                        if (call.method == "prepare_playback_file") {
                            val size = call.requiredLong("byte_size")
                            require(size in 1..3_000_000_000L)
                            val root = playbackDirectory()
                            require(StatFs(root.path).availableBytes >= size + 1_048_576)
                            val file = File(root, "${UUID.randomUUID()}.mp4")
                            val fd = Os.open(file.path, OsConstants.O_CREAT or OsConstants.O_EXCL or
                                OsConstants.O_WRONLY or OsConstants.O_NOFOLLOW, 0x180)
                            Os.close(fd)
                            try {
                                checkFile(file, 0)
                                playbackFiles.add(file.path)
                            } catch (error: Exception) {
                                require(file.delete() && stat(file) == null)
                                throw error
                            }
                            result.success(file.path)
                        } else {
                            val file = ownedFile(call.requiredString("output_path"))
                            if (call.method == "verify_playback_file") {
                                val size = call.requiredLong("byte_size")
                                require(size in 1..3_000_000_000L)
                                checkFile(file, size)
                            } else {
                                if (stat(file) != null) {
                                    checkFile(file, null)
                                    require(file.delete())
                                }
                                require(stat(file) == null)
                                playbackFiles.remove(file.path)
                            }
                            result.success(null)
                        }
                    }
                } catch (_: Exception) {
                    result.error("square_media_playback_failed", "本地播放文件保护、空间或清理检查失败", null)
                }
            }
            "cancel_video" -> {
                transcoder.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "citizenapp/square_media"
        private var playbackRoot: File? = null
        private val playbackFiles = mutableSetOf<String>()

        private fun stat(file: File): android.system.StructStat? = try {
            Os.lstat(file.path)
        } catch (error: ErrnoException) {
            if (error.errno == OsConstants.ENOENT) null else throw error
        }

        private fun checkFile(file: File, size: Long?) {
            val info = requireNotNull(stat(file))
            require(OsConstants.S_ISREG(info.st_mode) && info.st_uid == Process.myUid())
            require(info.st_mode and 0x1ff == 0x180 && file.canonicalPath == file.path)
            if (size != null) require(info.st_size == size)
        }
    }

    // 只使用凭据保护的私有缓存，不创建任何用途密钥或读取钱包存储。
    private fun playbackDirectory(): File {
        require(!storageContext.isDeviceProtectedStorage)
        playbackRoot?.let { return it }
        val root = File(storageContext.cacheDir.canonicalFile, "square_video_playback")
        if (stat(root) == null) Os.mkdir(root.path, 0x1c0)
        val info = requireNotNull(stat(root))
        require(OsConstants.S_ISDIR(info.st_mode) && info.st_uid == Process.myUid())
        require(root.canonicalPath == root.path)
        Os.chmod(root.path, 0x1c0)
        require(requireNotNull(stat(root)).st_mode and 0x1ff == 0x1c0)
        // 首次使用只删除此命名空间中的崩溃残留；未知文件或链接使播放失败。
        for (file in requireNotNull(root.listFiles())) {
            require(file.extension == "mp4")
            UUID.fromString(file.nameWithoutExtension)
            checkFile(file, null)
            require(file.delete() && stat(file) == null)
        }
        playbackRoot = root
        return root
    }

    private fun ownedFile(path: String): File {
        val root = playbackDirectory()
        val file = File(path)
        require(file.isAbsolute && file.parentFile == root && file.path == path)
        require(file.extension == "mp4" && playbackFiles.contains(path))
        UUID.fromString(file.nameWithoutExtension)
        return file
    }
}

data class SquareVideoRequest(
    val inputPath: String,
    val outputPath: String,
    val coverPath: String,
    val maxWidth: Int,
    val maxHeight: Int,
    val videoBitrate: Int,
    val totalPeakBitrate: Int,
    val audioBitrate: Int,
    val audioSampleRate: Int,
    val maxFrameRate: Int,
    val keyFrameIntervalSeconds: Int,
    val maxDurationSeconds: Int,
    val maxBytes: Long,
    val coverMaxEdge: Int,
    val coverQuality: Int,
    val coverMaxBytes: Int,
) {
    init {
        require(inputPath.isNotBlank() && outputPath.isNotBlank() && coverPath.isNotBlank()) {
            "媒体路径不能为空"
        }
        require(maxWidth in 2..1920 && maxHeight in 2..1080) { "视频尺寸不合法" }
        require(videoBitrate > 0 && audioBitrate > 0 && totalPeakBitrate > 0) { "视频码率不合法" }
        require(audioSampleRate == 48_000) { "音频采样率必须为 48kHz" }
        require(maxFrameRate in 1..30 && keyFrameIntervalSeconds == 2) { "帧率或关键帧间隔不合法" }
        require(maxDurationSeconds in 1..10_800 && maxBytes in 1..3_000_000_000L) { "视频上限不合法" }
        require(coverMaxEdge in 2..720 && coverQuality in 1..100 && coverMaxBytes in 1..512_000) {
            "视频封面规则不合法"
        }
    }

    companion object {
        fun from(call: MethodCall): SquareVideoRequest = SquareVideoRequest(
            inputPath = call.requiredString("input_path"),
            outputPath = call.requiredString("output_path"),
            coverPath = call.requiredString("cover_path"),
            maxWidth = call.requiredInt("max_width"),
            maxHeight = call.requiredInt("max_height"),
            videoBitrate = call.requiredInt("video_bitrate"),
            totalPeakBitrate = call.requiredInt("total_peak_bitrate"),
            audioBitrate = call.requiredInt("audio_bitrate"),
            audioSampleRate = call.requiredInt("audio_sample_rate"),
            maxFrameRate = call.requiredInt("max_frame_rate"),
            keyFrameIntervalSeconds = call.requiredInt("key_frame_interval_seconds"),
            maxDurationSeconds = call.requiredInt("max_duration_seconds"),
            maxBytes = call.requiredLong("max_bytes"),
            coverMaxEdge = call.requiredInt("cover_max_edge"),
            coverQuality = call.requiredInt("cover_quality"),
            coverMaxBytes = call.requiredInt("cover_max_bytes"),
        )
    }
}

private fun MethodCall.requiredString(key: String): String =
    argument<String>(key)?.takeIf { it.isNotBlank() }
        ?: throw IllegalArgumentException("$key 缺失")

private fun MethodCall.requiredInt(key: String): Int =
    (argument<Number>(key)?.toInt()) ?: throw IllegalArgumentException("$key 缺失")

private fun MethodCall.requiredLong(key: String): Long =
    (argument<Number>(key)?.toLong()) ?: throw IllegalArgumentException("$key 缺失")
