package com.crcfrcn.citizenapp

import android.net.Uri
import androidx.media3.datasource.DataSpec
import androidx.media3.common.util.UnstableApi
import java.io.IOException
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

