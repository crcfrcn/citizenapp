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

import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import android.widget.MediaController
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.BaseDataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformViewRegistry
import io.flutter.plugin.common.StandardMessageCodec
import java.io.IOException
import java.io.InterruptedIOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

// 历史媒体的本机安全读取顶，统一1024进制；会员成品额度仍由服务端交付。
private const val MAX_MEDIA_BYTES = 3L * 1024 * 1024 * 1024

/** 公民广场媒体原生入口；通道字段统一使用 snake_case。 */
class SquareMediaChannel(
    messenger: BinaryMessenger,
    context: Context,
    registry: PlatformViewRegistry? = null,
) {
    private val transcoder = SquareVideoTranscoder(context.applicationContext)
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val storageContext = context.applicationContext
    private var playbackInitializationFailed = false
    private val players = mutableMapOf<Int, SquarePlayer>()

    init {
        synchronized(playbackFiles) {
            try {
                playbackDirectory()
            } catch (_: Exception) {
                playbackInitializationFailed = true
            }
        }
        registry?.registerViewFactory("citizenapp/square_video", SquarePlayerFactory(channel, players))
        channel.setMethodCallHandler(::handle)
    }

    fun dispose() {
        transcoder.cancel()
        players.values.toList().forEach { it.dispose() }
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pause_playback", "dispose_playback" -> {
                val id = call.argument<Number>("player_id")?.toInt()
                if (call.method == "pause_playback") players[id]?.pause()
                else players[id]?.dispose()
                result.success(null)
            }
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
                            require(size in 1..MAX_MEDIA_BYTES)
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
                                require(size in 1..MAX_MEDIA_BYTES)
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
        require(maxDurationSeconds in 1..10_800 && maxBytes in 1..MAX_MEDIA_BYTES) { "视频上限不合法" }
        require(coverMaxEdge in 2..720 && coverQuality in 1..100 && coverMaxBytes in 1..512 * 1024) {
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

/** 原生只读取App交付的有界字节；没有URL、Token或第二套会员规则。 */
@UnstableApi
internal class SquareRangeSource(
    private val total: Long,
    private val readRange: (Long, Int) -> ByteArray,
) : BaseDataSource(false) {
    private var position = 0L
    private var remaining = 0L
    private var block = ByteArray(0)
    private var cursor = 0
    private var opened = false
    @Volatile private var closed = false
    private var spec: DataSpec? = null
    override fun open(dataSpec: DataSpec): Long {
        require(total > 0 && dataSpec.position in 0..total)
        transferInitializing(dataSpec)
        position = dataSpec.position
        remaining = if (dataSpec.length == C.LENGTH_UNSET.toLong()) total - position
            else minOf(dataSpec.length, total-position)
        spec = dataSpec
        closed = false
        opened = true
        transferStarted(dataSpec)
        return remaining
    }
    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        if (closed) throw IOException("playback_cancelled")
        if (remaining == 0L) return C.RESULT_END_OF_INPUT
        if (cursor == block.size) {
            val count = minOf(524288L, remaining).toInt()
            block = readRange(position, count)
            cursor = 0
            if (closed || block.size != count) throw IOException("invalid_media_range")
        }
        val count = minOf(length, block.size-cursor)
        block.copyInto(buffer, offset, cursor, cursor+count)
        cursor += count
        position += count
        remaining -= count
        bytesTransferred(count)
        return count
    }
    override fun getUri(): Uri? = spec?.uri
    override fun close() {
        closed = true
        block = ByteArray(0)
        cursor = 0
        spec = null
        if (opened) { opened = false; transferEnded() }
    }
}

@UnstableApi
private class SquarePlayerFactory(private val channel: MethodChannel, private val players: MutableMap<Int,SquarePlayer>) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val values = args as Map<*, *>
        val id = (values["player_id"] as Number).toInt()
        players[id]?.dispose()
        return SquarePlayer(context, channel, id, (values["byte_size"] as Number).toLong(),players)
    }
}

@UnstableApi
private class SquarePlayer(context: Context, private val channel: MethodChannel, private val id: Int, private val total: Long, private val players: MutableMap<Int,SquarePlayer>) : PlatformView {
    private val main = Handler(Looper.getMainLooper())
    private val root = FrameLayout(context)
    private val surface = SurfaceView(context)
    private val controls = MediaController(context)
    @Volatile private var disposed = false
    private val pending = mutableSetOf<CountDownLatch>()
    private val source = SquareRangeSource(total, ::read)
    private val player = ExoPlayer.Builder(context).build()
    init {
        require(total in 1..MAX_MEDIA_BYTES && !players.containsKey(id))
        players[id] = this
        root.addView(surface, FrameLayout.LayoutParams(-1,-1))
        player.setVideoSurfaceView(surface)
        controls.setAnchorView(root)
        controls.setMediaPlayer(object : MediaController.MediaPlayerControl {
            override fun start() = player.play()
            override fun pause() = player.pause()
            override fun getDuration() = player.duration.coerceAtLeast(0).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
            override fun getCurrentPosition() = player.currentPosition.toInt()
            override fun seekTo(position: Int) = player.seekTo(position.toLong())
            override fun isPlaying() = player.isPlaying
            override fun getBufferPercentage() = player.bufferedPercentage
            override fun canPause() = true
            override fun canSeekBackward() = true
            override fun canSeekForward() = true
            override fun getAudioSessionId() = player.audioSessionId
        })
        root.setOnTouchListener { _, _ -> controls.show(); true }
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                player.pause()
                if (!disposed) channel.invokeMethod("playback_failed", mapOf("player_id" to id))
            }
        })
        player.setMediaSource(ProgressiveMediaSource.Factory { source }
            .createMediaSource(MediaItem.fromUri("citizenmedia://player/$id")))
        player.prepare()
        player.play()
    }
    private fun read(offset: Long, length: Int): ByteArray {
        if (disposed || Looper.myLooper() == Looper.getMainLooper()) throw IOException("playback_cancelled")
        val latch = CountDownLatch(1)
        var bytes: ByteArray? = null
        synchronized(pending) { if (disposed) throw IOException("playback_cancelled"); pending.add(latch) }
        main.post {
            if (disposed) latch.countDown()
            else channel.invokeMethod("read_range", mapOf("player_id" to id, "offset" to offset, "length" to length), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val values = result as? Map<*, *>
                    if (!disposed && (values?.get("offset") as? Number)?.toLong() == offset &&
                        (values["total"] as? Number)?.toLong() == total && values["content_type"] == "video/mp4") {
                        bytes = values["bytes"] as? ByteArray
                    }
                    latch.countDown()
                }
                override fun error(code: String, message: String?, details: Any?) = latch.countDown()
                override fun notImplemented() = latch.countDown()
            })
        }
        val completed = try {
            latch.await(35, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            throw InterruptedIOException("playback_cancelled")
        } finally {
            synchronized(pending) { pending.remove(latch) }
        }
        if (!completed || disposed) throw IOException("playback_cancelled")
        return bytes?.takeIf { it.size == length } ?: throw IOException("invalid_media_range")
    }
    fun pause() { player.pause() }
    override fun getView(): View = root
    override fun dispose() {
        if (disposed) return
        disposed = true
        synchronized(pending) { pending.forEach { it.countDown() }; pending.clear() }
        controls.hide()
        player.release()
        source.close()
        players.remove(id)
    }
}
