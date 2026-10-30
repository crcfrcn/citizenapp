package com.crcfrcn.citizenapp

import android.os.Bundle
import android.os.Debug
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** 记录真实Release进程耗时与PSS；采样次数不是性能阈值，缺固定设备基线不能判达标。 */
@RunWith(AndroidJUnit4::class)
class PerformanceInstrumentedTest {
    @Test fun launch() = sample("launch", before = {}, action = {
        AppFlowInstrumentedTest.launch(); AppFlowInstrumentedTest.ready()
    })

    @Test fun creatorEntry() = sample("creatorEntry", before = { AppFlowInstrumentedTest.main() }, action = {
        AppFlowInstrumentedTest.creator()
    })

    @Test fun walletScroll() {
        AppFlowInstrumentedTest.main(); AppFlowInstrumentedTest.tab("我的"); AppFlowInstrumentedTest.tap("钱包")
        val indices = mutableSetOf<Int>()
        repeat(12) {
            indices.addAll(AppFlowInstrumentedTest.nodes().mapNotNull { AppFlowInstrumentedTest.accountIndex(it) })
            val scroll = AppFlowInstrumentedTest.nodes().firstOrNull { it.isScrollable }
            scroll?.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
            AppFlowInstrumentedTest.instrumentation.waitForIdleSync()
        }
        assumeTrue("须预置至少20个已有账户的长列表", indices.size >= 20)
        sample("walletScroll", before = {
            AppFlowInstrumentedTest.main(); AppFlowInstrumentedTest.tab("我的"); AppFlowInstrumentedTest.tap("钱包")
        }, action = { AppFlowInstrumentedTest.scroll() })
    }

    @Test fun mediaTranscode() {
        val context = AppFlowInstrumentedTest.context
        val name = InstrumentationRegistry.getArguments().getString("media_fixture") ?: ""
        assumeTrue("须提供隔离缓存内的合成视频夹具", name.matches(Regex("[A-Za-z0-9_-]+\\.mp4")))
        val input = File(context.cacheDir, name)
        assumeTrue("夹具必须为本应用缓存内的普通视频", input.isFile && input.canonicalFile.parentFile == context.cacheDir.canonicalFile)
        val transcoder = SquareVideoTranscoder(context)
        assumeTrue("须具备真实HEVC硬件编解码能力", transcoder.capabilities().values.all { it })
        sample("mediaTranscode", before = {}, action = {
            val directory = File(context.cacheDir, UUID.randomUUID().toString()).apply { mkdir() }
            try {
                val output = File(directory,"output.mp4"); val cover = File(directory,"cover.jpg")
                val request = SquareVideoRequest.from(MethodCall("transcode_video", mapOf(
                    "input_path" to input.path,"output_path" to output.path,"cover_path" to cover.path,
                    "video_width" to 854,"video_height" to 480,"video_bitrate" to 386000,
                    "video_peak_bitrate" to 675000,"audio_bitrate" to 64000,"audio_sample_rate" to 48000,
                    "video_frame_rate" to 30,"keyframe_secs" to 2,"video_max_seconds" to 180,
                    "video_max_bytes" to 12 * 1024 * 1024,"cover_dimension" to 540,"cover_quality" to 70,"cover_bytes" to 120 * 1024)))
                val done = CountDownLatch(1); var passed = false
                AppFlowInstrumentedTest.instrumentation.runOnMainSync {
                    transcoder.transcode(request,object: MethodChannel.Result {
                        override fun success(result: Any?) { passed = result is Map<*,*>; done.countDown() }
                        override fun error(code: String,message: String?,details: Any?) { done.countDown() }
                        override fun notImplemented() { done.countDown() }
                    })
                }
                assertTrue("真实转码超时", done.await(180,TimeUnit.SECONDS))
                assertTrue("真实转码失败", passed && output.length() > 0 && cover.length() > 0)
            } finally { AppFlowInstrumentedTest.instrumentation.runOnMainSync { transcoder.cancel() }; directory.deleteRecursively() }
        })
    }

    private fun sample(name: String, before: () -> Unit, action: () -> Unit) {
        val samples = JSONArray()
        repeat(5) {
            before()
            val started = SystemClock.elapsedRealtimeNanos(); action()
            val elapsed = SystemClock.elapsedRealtimeNanos() - started
            val memory = Debug.MemoryInfo(); Debug.getMemoryInfo(memory)
            samples.put(JSONObject().put("elapsed_ns",elapsed).put("pss_kb",memory.totalPss))
        }
        val data = JSONObject().put("test",javaClass.name + "#" + name).put("samples",samples)
        AppFlowInstrumentedTest.instrumentation.sendStatus(2,Bundle().apply { putString("citizenapp_metrics",data.toString()) })
    }
}
