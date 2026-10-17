package com.crcfrcn.citizenapp

import android.Manifest
import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val securityChannelName = "citizenapp/security"
    private val updateChannelName = "citizenapp/update"
    private val permissionsChannelName = "citizenapp/permissions"
    private var squareMediaChannel: SquareMediaChannel? = null
    private val notificationPermissionRequestCode = 170517
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    companion object {
        // 与 Cloudflare Worker FCM payload 的 android.notification.channel_id 一致。
        private const val SQUARE_POST_CHANNEL_ID = "square_posts"
        private const val CHAT_NOTIFICATION_CHANNEL_ID = "chat_messages"
        private const val CHAT_NOTIFICATION_METHOD_CHANNEL = "citizenapp/chat_notifications"
    }

    /**
     * 已运行时的钱包回跳只把原 Activity 拉回前台。WalletConnect 响应仍由 WebView 中的
     * provider 经 Relay 收取，不把 citizenapp://walletconnect 继续发送成 Flutter 路由。
     */
    override fun onNewIntent(intent: Intent) {
        if (isWalletConnectCallback(intent.data)) {
            setIntent(intent)
            return
        }
        super.onNewIntent(intent)
    }

    private fun isWalletConnectCallback(uri: Uri?): Boolean =
        uri?.scheme.equals("citizenapp", ignoreCase = true) &&
            uri?.host.equals("walletconnect", ignoreCase = true)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ensureSquarePostNotificationChannel()
        ensureChatNotificationChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHAT_NOTIFICATION_METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showChatNotification" -> {
                    val conversationId = call.argument<String>("conversationId")
                        ?.takeIf { it.isNotBlank() }
                    val envelopeId = call.argument<String>("envelopeId")
                        ?.takeIf { it.isNotBlank() }
                    if (conversationId == null || envelopeId == null) {
                        result.error("INVALID_NOTIFICATION_TAG", "聊天通知缺少会话标识", null)
                        return@setMethodCallHandler
                    }
                    showChatNotification(conversationId, envelopeId)
                    result.success(null)
                }
                "clearConversationNotifications" -> {
                    val conversationId = call.argument<String>("conversationId")
                        ?.takeIf { it.isNotBlank() }
                    if (conversationId == null) {
                        result.error("INVALID_CONVERSATION_ID", "聊天通知缺少会话标识", null)
                        return@setMethodCallHandler
                    }
                    clearChatNotifications(conversationId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        squareMediaChannel = SquareMediaChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableScreenshotProtection" -> {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        result.success(null)
                    }
                    "disableScreenshotProtection" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "beginEmergencyWipe" -> {
                        // 先把任务移出最近使用界面，但不 finish Activity，保留 Flutter
                        // 引擎继续清除密钥与数据；进程若被系统终止则由 pending 门闩恢复。
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "finishEmergencyWipe" -> {
                        // 先回复 Dart，下一轮主线程消息再移除任务，避免通道响应被销毁截断。
                        result.success(null)
                        window.decorView.post { finishAndRemoveTask() }
                    }
                    "isDeviceRooted" -> {
                        result.success(checkRoot())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "getNotificationPermissionStatus" ->
                        result.success(isNotificationPermissionGranted())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "citizenapp/system_protected_data")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "prepareRecords" -> result.success(prepareProtectedRecords())
                        "protectUserDatabase" -> {
                            val directory = call.argument<String>("directory") ?: throw IllegalArgumentException()
                            require(File(directory).absolutePath == filesDir.canonicalPath)
                            protectAppDirectory(filesDir.canonicalFile)
                            for (file in filesDir.listFiles() ?: throw IllegalStateException()) {
                                if (file.name == "citizenapp_user.isar" || file.name.startsWith("citizenapp_user.isar.")) {
                                    require(file.isFile && file.absolutePath == file.canonicalPath)
                                    android.system.Os.chmod(file.path, 384)
                                    require((android.system.Os.stat(file.path).st_mode and 511) == 384)
                                }
                            }
                            result.success(null)
                        }
                        "compareRecords" -> { result.success(compareProtectedRecord(call)) }
                        "eraseObsoleteDataMaterial" -> { eraseObsoleteDataMaterial(); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("system_protection_unavailable", "系统保护存储不可用", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPackageInfo" -> {
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "packageName" to packageName,
                                "versionName" to (packageInfo.versionName ?: ""),
                                "versionCode" to versionCode,
                            )
                        )
                    }
                    "installApk" -> {
                        val apkPath = call.argument<String>("apkPath")
                        if (apkPath.isNullOrBlank()) {
                            result.error("INVALID_APK_PATH", "APK 路径为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(installApk(File(apkPath)))
                        } catch (error: Exception) {
                            result.error(
                                "INSTALL_APK_FAILED",
                                error.message ?: "拉起系统安装器失败",
                                null
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        squareMediaChannel?.dispose()
        squareMediaChannel = null
        super.onDestroy()
    }

    /// 广场发帖通知渠道（Android 8+）：高优先级=横幅+系统提示音。FCM payload 的
    /// channel_id='square_posts' 命中此渠道；不建则声音由系统默认渠道决定（可能无声）。
    private fun ensureSquarePostNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(SQUARE_POST_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            SQUARE_POST_CHANNEL_ID,
            "广场动态",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "关注的人发布新动态/文章时通知"
            enableVibration(true)
            // IMPORTANCE_HIGH 渠道默认带系统提示音，不覆盖 sound 即用默认铃声。
        }
        manager.createNotificationChannel(channel)
    }

    /// 聊天消息独立使用高优先级渠道；用户可以在系统设置中单独关闭，App 不绕过该选择。
    private fun ensureChatNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHAT_NOTIFICATION_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHAT_NOTIFICATION_CHANNEL_ID,
            "聊天消息",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "收到新的端到端加密消息时通知"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    /// FCM 前台消息不会自动弹出通知；这里只展示固定无正文文案，不接收聊天内容。
    private fun showChatNotification(conversationId: String, envelopeId: String) {
        if (!isNotificationPermissionGranted()) return
        val tag = "$conversationId|$envelopeId"
        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            tag.hashCode(),
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHAT_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("公民")
            .setContentText("你有一条新消息")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        NotificationManagerCompat.from(this).notify(tag, 1, notification)
    }

    /// 只清除目标会话的聊天通知；tag 前缀使用既有 conversation_id，禁止 cancelAll
    /// 误删其它聊天、广场或系统通知。
    private fun clearChatNotifications(conversationId: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val prefix = "$conversationId|"
        manager.activeNotifications
            .filter { notification ->
                notification.tag?.startsWith(prefix) == true &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        notification.notification.channelId == CHAT_NOTIFICATION_CHANNEL_ID)
            }
            .forEach { notification -> manager.cancel(notification.tag, notification.id) }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (isNotificationPermissionGranted()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "通知权限申请正在进行中", null)
            return
        }

        // 通知权限只在用户确认首启说明后申请；拒绝不会阻塞 App 使用。
        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == notificationPermissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun installApk(apkFile: File): Boolean {
        if (!apkFile.exists()) {
            throw IllegalArgumentException("APK 文件不存在: ${apkFile.absolutePath}")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            // Android 8+ 必须由用户授权“允许安装未知应用”，App 不能绕过系统确认。
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
            return false
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.update_file_provider",
            apkFile
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return true
    }

    private fun checkRoot(): Boolean {
        val suPaths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/data/local/su", "/su/bin/su",
            "/system/app/Superuser.apk",
            "/system/app/SuperSU.apk",
        )
        for (path in suPaths) {
            if (File(path).exists()) return true
        }
        val buildTags = android.os.Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true
        if (File("/sbin/.magisk").exists()) return true
        if (File("/data/adb/magisk").exists()) return true
        return false
    }
    /** 平台给出的凭据加密根是唯一允许入口；不接受外部目录或设备保护存储。 */
    private fun protectAppDirectory(directory: File): File {
        require(!isDeviceProtectedStorage) { "凭据加密存储不可用" }
        if (android.os.Build.VERSION.SDK_INT >= 24) {
            val users = getSystemService(android.os.UserManager::class.java)
            require(users != null && users.isUserUnlocked) { "系统保护存储不可用" }
        }
        val support = filesDir.canonicalFile
        require(directory.absoluteFile.path == directory.canonicalPath)
        require(directory.canonicalPath == support.path ||
            directory.canonicalPath.startsWith(support.path + File.separator))
        require(directory.exists() || directory.mkdirs())
        require(directory.isDirectory && directory.setReadable(false, false) &&
            directory.setWritable(false, false) && directory.setExecutable(false, false))
        require(directory.setReadable(true, true) && directory.setWritable(true, true) &&
            directory.setExecutable(true, true))
        require((android.system.Os.stat(directory.path).st_mode and 511) == 448)
        return directory
    }

    private fun prepareProtectedRecords(): String {
        val root = protectAppDirectory(File(filesDir.canonicalFile, "citizenapp_records"))
        for (file in root.listFiles() ?: throw IllegalStateException("记录目录不可读")) {
            require(isCitizenProtectedRecordName(file.name, auxiliary = true) && file.isFile && file.absolutePath == file.canonicalPath)
            require(file.setReadable(false, false) && file.setWritable(false, false) &&
                file.setReadable(true, true) && file.setWritable(true, true))
            require((android.system.Os.stat(file.path).st_mode and 511) == 384)
        }
        // 只用API 21起公开的目录操作：拒绝末端链接及FIFO阻塞，并以实际描述符核验目录。
        val descriptor = android.system.Os.open(root.path, android.system.OsConstants.O_RDONLY or
            android.system.OsConstants.O_NOFOLLOW or android.system.OsConstants.O_NONBLOCK, 0)
        try {
            val metadata = android.system.Os.fstat(descriptor)
            require(android.system.OsConstants.S_ISDIR(metadata.st_mode) &&
                metadata.st_uid == android.os.Process.myUid() && (metadata.st_mode and 511) == 448) {
                "记录目录属性无效"
            }
            android.system.Os.fsync(descriptor)
        } finally { android.system.Os.close(descriptor) }
        return root.path
    }

    /** 原生比较与提交在同一文件锁内完成，拒绝其他isolate已经提交的旧快照。 */
    private fun compareProtectedRecord(call: io.flutter.plugin.common.MethodCall): Boolean {
        val args = call.arguments as? Map<*, *> ?: throw IllegalArgumentException("记录参数无效")
        require(args.keys == setOf("name", "expected", "next"))
        val name = args["name"] as? String ?: throw IllegalArgumentException("记录名称无效")
        require(isCitizenProtectedRecordName(name))
        val expected = args["expected"]
        require(expected == null || expected is String)
        val next = args["next"] as? String ?: throw IllegalArgumentException("记录内容无效")
        val bytes = next.toByteArray(Charsets.UTF_8)
        require(bytes.size <= 262144)
        val parsed = org.json.JSONObject(next)
        for (key in parsed.keys()) require(parsed.get(key) is String)
        val root = File(prepareProtectedRecords())
        val target = File(root, name)
        val part = File(root, name + ".part")
        val lock = File(root, name + ".lock")
        java.io.RandomAccessFile(lock, "rw").use { handle ->
            handle.channel.lock().use {
                require(target.absolutePath == target.canonicalPath && part.absolutePath == part.canonicalPath)
                val current = if (target.exists()) target.readText(Charsets.UTF_8) else null
                if (current != expected) return false
                android.system.Os.chmod(lock.path, 384)
                java.io.FileOutputStream(part).use { output ->
                    android.system.Os.chmod(part.path, 384)
                    output.write(bytes); output.fd.sync()
                }
                android.system.Os.rename(part.path, target.path)
                prepareProtectedRecords()
                check(target.readText(Charsets.UTF_8) == next)
                return true
            }
        }
    }

    /** 旧材料只允许精确删除，不能生成、解封或转成新存储。 */
    private fun eraseObsoleteDataMaterial() {
        val keys = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val pluginAliases = setOf(packageName + ".FlutterSecureStoragePluginKey",
            packageName + ".FlutterSecureStoragePluginKeyOAEP")
        for (alias in keys.aliases().toList()) {
            if (Regex("^citizen_device_data_key_[0-9]+$").matches(alias) || alias in pluginAliases) {
                keys.deleteEntry(alias)
                check(!keys.containsAlias(alias)) { "旧App数据材料仍存在" }
            }
        }
        for (name in listOf("FlutterSecureStorage", "FlutterSecureKeyStorage")) {
            val preferences = getSharedPreferences(name, android.content.Context.MODE_PRIVATE)
            check(preferences.edit().clear().commit() && preferences.all.isEmpty())
        }
    }


}

/** 主记录及辅助锁/残片的唯一白名单；原生检查仍逐项验证文件类型与路径。 */
internal fun isCitizenProtectedRecordName(name: String, auxiliary: Boolean = false): Boolean {
    val main = setOf("identity.json", "lock.json", "registration.json")
    return name in main || (auxiliary && main.any { name == "$it.lock" || name == "$it.part" })
}
