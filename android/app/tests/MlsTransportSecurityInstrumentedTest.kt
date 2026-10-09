package com.crcfrcn.citizenapp

import android.security.NetworkSecurityPolicy
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertFalse
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
