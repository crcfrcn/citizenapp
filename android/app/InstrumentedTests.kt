package com.crcfrcn.citizenapp

import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ApplicationInfo
import android.security.NetworkSecurityPolicy
import android.system.Os
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.MethodCall
import java.io.ByteArrayOutputStream
import java.io.File
import java.lang.reflect.InvocationTargetException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** 验证MLS认证与聊天所依赖的系统传输边界；不访问网络、钱包或设备存储。 */
@RunWith(AndroidJUnit4::class)
class MlsTransportSecurityInstrumentedTest {
    @Test
    fun applicationPolicyRejectsCleartextForPublicAndLocalHosts() {
        val policy = NetworkSecurityPolicy.getInstance()
        assertFalse(policy.isCleartextTrafficPermitted)
        for (host in listOf("www.crcfrcn.com", "localhost", "127.0.0.1")) {
            assertFalse(host, policy.isCleartextTrafficPermitted(host))
        }
    }
}

/** 使用生产原生CAS，测试根严格隔离，绝不读写用户的正式registration记录。 */
@RunWith(AndroidJUnit4::class)
class RegistrationRecordSecurityInstrumentedTest {
    @Test fun nativeRecordWhitelistSeparatesMainAndAuxiliaryFiles() {
        assertTrue(isCitizenProtectedRecordName("registration.json"))
        assertTrue(isCitizenProtectedRecordName("topup.json"))
        assertFalse(isCitizenProtectedRecordName("topup.json.part"))
        assertTrue(isCitizenProtectedRecordName("topup.json.part", auxiliary = true))
        assertFalse(isCitizenProtectedRecordName("../topup.json"))
        for (name in listOf("registration.json.lock", "registration.json.part")) {
            assertTrue(isCitizenProtectedRecordName(name, auxiliary = true))
            assertFalse(isCitizenProtectedRecordName(name))
        }
        for (name in listOf("registration.json/../identity.json", "../registration.json", "unknown.json")) {
            assertFalse(isCitizenProtectedRecordName(name, auxiliary = true))
        }
    }

    @Test fun productionCasRejectsStaleWritesLinksAndTraversal() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val isolated = File(context.filesDir, "app8_registration_test_" + UUID.randomUUID()).canonicalFile
        check(isolated.mkdirs())
        try {
            assertEquals(0, context.applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP)
            instrumentation.runOnMainSync {
                val activity = MainActivity()
                // 不启动Flutter、钱包或网络；仅把生产存储通道绑定到本测试独占的凭据加密根。
                val base = object : ContextWrapper(context) {
                    override fun getFilesDir(): File = isolated
                }
                ContextWrapper::class.java.getDeclaredMethod("attachBaseContext", Context::class.java).apply {
                    isAccessible = true
                }.invoke(activity, base)
                val compare = MainActivity::class.java.getDeclaredMethod("compareProtectedRecord", MethodCall::class.java).apply {
                    isAccessible = true
                }
                fun cas(name: String, expected: String?, next: String): Boolean =
                    compare.invoke(activity, MethodCall("compareRecords", mapOf("name" to name, "expected" to expected, "next" to next))) as Boolean
                fun rejected(block: () -> Unit) {
                    try { block(); fail("必须拒绝越界或链接") }
                    catch (error: InvocationTargetException) { assertTrue(error.cause is Exception) }
                }
                val first = "{\"context\":\"recovery-capability\"}"
                assertTrue(cas("registration.json", null, first))
                assertFalse(cas("registration.json", null, "{}"))
                val root = File(isolated, "citizenapp_records")
                val record = File(root, "registration.json")
                assertEquals(first, record.readText())
                assertEquals(384, Os.stat(record.path).st_mode and 511)
                assertEquals(448, Os.stat(root.path).st_mode and 511)
                assertFalse(File(root, "registration.json.part").exists())
                rejected { cas("../registration.json", null, "{}") }
                rejected { cas("unknown.json", null, "{}") }
                check(record.delete())
                val outside = File(isolated, "outside").apply { writeText("unchanged") }
                Os.symlink(outside.path, record.path)
                rejected { cas("registration.json", null, "{}") }
                assertEquals("unchanged", outside.readText())
                check(record.delete())
                assertTrue(cas("registration.json", null, "{}"))
                check(record.delete())
                assertFalse(record.exists())
            }
        } finally { check(isolated.deleteRecursively()) }
    }
}

/** 广场媒体原生契约的 Android 设备级测试；不读写相册、账户或远端存储。 */
@RunWith(AndroidJUnit4::class)
class SquareMediaChannelInstrumentedTest {
    @Test
    fun requestAcceptsOnlyThePublishedCodecEnvelope() {
        val request = SquareVideoRequest.from(MethodCall("transcode_video", validArguments()))
        assertEquals(854, request.maxWidth)
        assertEquals(48_000, request.audioSampleRate)
        assertEquals(2, request.keyFrameIntervalSeconds)

        val invalid = validArguments().toMutableMap().apply { this["audio_sample_rate"] = 44_100 }
        assertThrows(IllegalArgumentException::class.java) {
            SquareVideoRequest.from(MethodCall("transcode_video", invalid))
        }
    }

    @Test
    fun capabilitiesAlwaysReportBothFailClosedFlags() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val capabilities = SquareVideoTranscoder(context).capabilities()
        assertEquals(setOf("can_encode_hevc", "can_decode_hevc"), capabilities.keys)
        assertEquals(2, capabilities.values.size)
    }

    @Test
    fun fastStartMovesMoovAndPatchesChunkOffset() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val file = File(context.cacheDir, "square-faststart-test.mp4")
        file.delete()
        val ftyp = atom("ftyp", byteArrayOf())
        val mdat = atom("mdat", byteArrayOf(1, 2, 3, 4))
        val oldChunkOffset = ftyp.size + 8
        val stcoPayload = ByteBuffer.allocate(12).order(ByteOrder.BIG_ENDIAN)
            .putInt(0)
            .putInt(1)
            .putInt(oldChunkOffset)
            .array()
        val stbl = atom("stbl", atom("stco", stcoPayload))
        val minf = atom("minf", stbl)
        val mdia = atom("mdia", minf)
        val trak = atom("trak", mdia)
        val moov = atom("moov", trak)
        file.writeBytes(ftyp + mdat + moov)
        assertFalse(SquareMp4FastStart.isFastStart(file))

        SquareMp4FastStart.optimize(file)

        assertTrue(SquareMp4FastStart.isFastStart(file))
        val bytes = file.readBytes()
        val stcoIndex = bytes.indexOfSlice("stco".toByteArray())
        val patchedOffset = ByteBuffer.wrap(bytes, stcoIndex + 12, 4)
            .order(ByteOrder.BIG_ENDIAN)
            .int
        assertEquals(oldChunkOffset + moov.size, patchedOffset)
        file.delete()
    }

    private fun validArguments(): Map<String, Any> = mapOf(
        "input_path" to "/tmp/input.mov",
        "output_path" to "/tmp/output.mp4",
        "cover_path" to "/tmp/cover.png",
        "max_width" to 854,
        "max_height" to 480,
        "video_bitrate" to 504_000,
        "total_peak_bitrate" to 900_000,
        "audio_bitrate" to 96_000,
        "audio_sample_rate" to 48_000,
        "max_frame_rate" to 30,
        "key_frame_interval_seconds" to 2,
        "max_duration_seconds" to 180,
        "max_bytes" to 16_000_000L,
        "cover_max_edge" to 720,
        "cover_quality" to 75,
        "cover_max_bytes" to 512_000,
    )

    private fun atom(type: String, payload: ByteArray): ByteArray = ByteArrayOutputStream().use { output ->
        output.write(ByteBuffer.allocate(4).order(ByteOrder.BIG_ENDIAN).putInt(payload.size + 8).array())
        output.write(type.toByteArray())
        output.write(payload)
        output.toByteArray()
    }

    private fun ByteArray.indexOfSlice(needle: ByteArray): Int {
        for (index in 0..size - needle.size) {
            if (needle.indices.all { this[index + it] == needle[it] }) return index
        }
        error("未找到目标字节序列")
    }
}
