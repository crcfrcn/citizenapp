package com.crcfrcn.citizenapp

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Rect
import android.os.Build
import android.os.SystemClock
import android.view.KeyEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** 只操作已有隔离账户的页面；不输入账户、金额、身份凭据，不发送或提交。 */
@RunWith(AndroidJUnit4::class)
class AppFlowInstrumentedTest {
    @Test fun startupGateSurvivesRelaunch() {
        launch()
        val gate = ready()
        launch()
        assertEquals("Activity重建后启动门禁不一致", gate, ready())
    }

    @Test fun tradeWalletSelectionReturnsToEmptyForm() {
        main()
        tab("交易")
        for (index in listOf(0,1,0)) {
            tap("选择交易钱包")
            val rows = hotRows()
            assumeTrue("须预置两个可见热账户；不自动建账户", rows.size >= 2)
            val selectedIndex = accountIndex(rows[index])!!
            click(rows[index])
            emptyTrade()
            await { nodes().any { labels(it).any { text ->
                text.split(", ", "\n").any { part -> part.trim() == "当前付款账户：#$selectedIndex" }
            } } }
        }
    }

    @Test fun scannerReturnsToEmptyForm() {
        main(); tab("交易"); tap("扫码填入收款地址")
        // 不自动授予系统相机权限；隔离设备须预先完成权限设置。
        assumeTrue("须预置相机权限", nodes().any { it.packageName?.toString() == packageName })
        back(); emptyTrade()
    }

    @Test fun creatorEntryDisplaysImmediately() {
        main(); creator()
    }

    @Test fun chatResumesWithoutSending() {
        main(); tab("聊天"); chatReady()
        instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_HOME)
        val intent = context.packageManager.getLaunchIntentForPackage(packageName)!!
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        await { node("聊天") != null }; chatReady()
    }

    companion object {
        internal val instrumentation get() = InstrumentationRegistry.getInstrumentation()
        internal val context get() = instrumentation.targetContext
        internal const val packageName = "com.crcfrcn.citizenapp"
        internal fun launch() {
            assertEquals(packageName, context.packageName)
            assertEquals("必须使用Release目标", 0, context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE)
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)!!
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            instrumentation.startActivitySync(intent)
        }
        internal fun nodes(): List<AccessibilityNodeInfo> {
            val result = mutableListOf<AccessibilityNodeInfo>()
            val root = instrumentation.uiAutomation.rootInActiveWindow
            val window = Rect(); root?.getBoundsInScreen(window)
            fun visit(node: AccessibilityNodeInfo?) {
                if (node == null) return
                val bounds = Rect(); node.getBoundsInScreen(bounds)
                if (node.packageName?.toString() == packageName && node.isVisibleToUser && Rect.intersects(window,bounds)) result.add(node)
                for (i in 0 until node.childCount) visit(node.getChild(i))
            }
            visit(root)
            return result
        }
        // Flutter官方桥对普通控件写contentDescription，对输入框写text/hintText；Tab提示用逗号合并。
        internal fun labels(node: AccessibilityNodeInfo): List<String> = listOfNotNull(
            node.text,node.contentDescription,
            if (Build.VERSION.SDK_INT >= 28) node.hintText else null,
            if (Build.VERSION.SDK_INT >= 28) node.tooltipText else null,
        ).map { it.toString() }
        internal fun node(label: String) = nodes().firstOrNull { item ->
            labels(item).any { it.split(", ", "\n").any { part -> part.trim() == label } }
        }
        internal fun accountIndex(node: AccessibilityNodeInfo): Int? = labels(node).firstNotNullOfOrNull {
            Regex("(?s)^#([0-9]+)(?:[\\s,].*)?$").matchEntire(it)?.groupValues?.get(1)?.toIntOrNull()
        }
        internal fun hotRows() = nodes().filter { accountIndex(it) != null }.distinctBy { accountIndex(it) }
        internal fun await(timeout: Long = 10000, predicate: () -> Boolean) {
            val end = SystemClock.elapsedRealtime() + timeout
            while (true) {
                val ready = predicate()
                assertTrue("等待指定页面超时", SystemClock.elapsedRealtime() <= end)
                if (ready) return
                SystemClock.sleep(50) // 即使条件迟到才成立，也必须核对截止时间。
            }
        }
        internal fun click(node: AccessibilityNodeInfo) {
            var target: AccessibilityNodeInfo? = node
            while (target != null && !target.isClickable) target = target.parent
            assertTrue("页面控件不可点击", target?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true)
        }
        internal fun tap(label: String) { await { node(label) != null }; click(node(label)!!) }
        internal fun tab(label: String) { tap(label) }
        internal fun back() { instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK) }
        internal fun ready(): Boolean {
            await(30000) { node("创建钱包") != null || node("聊天") != null || node("稍后再说") != null }
            node("稍后再说")?.let { click(it) }
            await(30000) { node("创建钱包") != null || node("聊天") != null }
            return node("创建钱包") != null
        }
        internal fun main() { launch(); assumeTrue("须预置已解锁隔离账户", !ready()) }
        internal fun emptyTrade() {
            await { node("扫码填入收款地址") != null && node("选择交易钱包") != null && nodes().count { it.isEditable } >= 2 }
            val fields = nodes().filter { it.isEditable }
            assertTrue("返回后表单必须保持全部空值", fields.all { it.text.isNullOrEmpty() })
        }
        internal fun creator() {
            tab("我的"); await { node("我的用户码") != null }; await { node("创作者") != null }
            val started = SystemClock.elapsedRealtime()
            click(node("创作者")!!)
            await(1000) { nodes().any { n -> listOf(n.text,n.contentDescription).any { t -> t?.contains("我的创作者会员") == true || t?.contains("去订阅平台会员") == true } } }
            assertTrue("点击至创作者内容就绪须在1秒内", SystemClock.elapsedRealtime() - started <= 1000)
        }
        internal fun chatReady() {
            await(30000) { node("新建") != null }
            await(30000) { node("正在读取本地会话") == null }
            assertNull(node("聊天暂时无法使用，请稍后重试"))
            assertNull(node("验证并准备聊天与通讯录密钥"))
        }
        internal fun scroll() {
            val scroll = nodes().firstOrNull { it.isScrollable }
            assertTrue("真实列表不可滚动", scroll?.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) == true)
            instrumentation.waitForIdleSync()
        }
    }
}
