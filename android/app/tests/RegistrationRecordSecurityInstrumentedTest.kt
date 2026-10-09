package com.crcfrcn.citizenapp

import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ApplicationInfo
import android.system.Os
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.MethodCall
import java.io.File
import java.lang.reflect.InvocationTargetException
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** 使用生产原生CAS，测试根严格隔离，绝不读写用户的正式registration记录。 */
@RunWith(AndroidJUnit4::class)
class RegistrationRecordSecurityInstrumentedTest {
    @Test fun nativeRecordWhitelistSeparatesMainAndAuxiliaryFiles() {
        assertTrue(isCitizenProtectedRecordName("registration.json"))
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
