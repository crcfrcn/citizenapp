package com.crcfrcn.citizenapp;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.UserManager;
import android.system.Os;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Pattern;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

import io.flutter.plugin.common.BinaryMessenger;

/** 聊天数据库与 MLS 的独立系统保护目录。 */
public final class ChatStorageChannel {
 private final Context applicationContext;
 private final MethodChannel securityChannel;
 public ChatStorageChannel(Context context, BinaryMessenger messenger) {
 applicationContext = context.getApplicationContext();
        securityChannel = new MethodChannel(messenger, "citizenapp/chat/storage", io.flutter.plugin.common.StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue());
        securityChannel.setMethodCallHandler((call, result) -> {
            if ("eraseMlsStorage".equals(call.method)) {
                try { eraseMlsStorage(call); result.success(null); }
                catch (Exception error) { result.error("mls_storage_unavailable", "MLS安全存储清理失败", null); }
                return;
            }
            if ("prepareDataStorage".equals(call.method)) {
                try { result.success(prepareDataStorage()); }
                catch (Exception error) { result.error("data_storage_unavailable", "聊天系统保护存储不可用", null); }
                return;
            }
            if (!"prepareMlsStorage".equals(call.method)) { result.notImplemented(); return; }
            try { result.success(prepareMlsStorage(call)); }
            catch (Exception error) { result.error("mls_storage_unavailable", "MLS安全存储不可用", null); }
        });
 }
 public void dispose() { securityChannel.setMethodCallHandler(null); }
    /** 聊天所属 CE 非备份目录；权限、路径和每个现有侧文件均回读。 */
    private String prepareDataStorage() throws Exception {
        Context context = applicationContext;
        if (context == null || context.isDeviceProtectedStorage()) throw new IOException("storage unavailable");
        UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
        if (users == null || !users.isUserUnlocked()) throw new IOException("storage locked");
        // 准备时只搬移旧命名目录与文件，保留已有字节；保护验证失败即拒绝访问。
        File root = migrateDirectory(context.getNoBackupFilesDir().getCanonicalFile(), "tatachat_sdk_data", "chat_data");
        if (!root.exists() && !root.mkdir()) throw new IOException("mkdir failed");
        protectOwnedTree(root);
        return root.getCanonicalPath();
    }
    static void protectOwnedTree(File file) throws Exception {
        if (!file.getCanonicalPath().equals(file.getAbsolutePath())) throw new IOException("symlink");
        int permissions = file.isDirectory() ? 0700 : 0600;
        if (!file.isDirectory() && !file.isFile()) throw new IOException("invalid file");
        Os.chmod(file.getAbsolutePath(), permissions);
        if ((Os.stat(file.getAbsolutePath()).st_mode & 0777) != permissions) throw new IOException("permissions failed");
        if (file.isDirectory()) {
            File[] entries = file.listFiles();
            if (entries == null) throw new IOException("list failed");
            for (File entry : entries) protectOwnedTree(entry);
        }
    }

    /** 只删除聊天自有目录，不读取或清空宿主安全存储。 */
    private void eraseMlsStorage(MethodCall call) throws Exception {
        Context context = applicationContext;
        if (context == null || context.isDeviceProtectedStorage()) throw new IOException("storage unavailable");
        UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
        if (users == null || !users.isUserUnlocked()) throw new IOException("storage locked");
        File target = migrateDirectory(context.getNoBackupFilesDir().getCanonicalFile(), "tatachat_sdk_mls", "chat_mls");
        if (call.hasArgument("user_id")) {
            String user = call.argument("user_id");
            if (user == null || user.trim().isEmpty() || user.contains(":")) throw new IOException("invalid owner");
            byte[] bytes = user.getBytes(StandardCharsets.UTF_8);
            if (bytes.length > 120) throw new IOException("invalid owner length");
            StringBuilder name = new StringBuilder();
            for (byte value : bytes) name.append(String.format(Locale.ROOT, "%02x", value & 255));
            target = new File(target, name.toString());
        }
        eraseOwnedMlsDirectory(target);
    }
    private static void eraseOwnedMlsDirectory(File directory) throws IOException {
        if (!directory.getCanonicalPath().equals(directory.getAbsolutePath())) throw new IOException("symlink");
        if (!directory.exists()) return;
        if (directory.isDirectory()) {
            File[] entries = directory.listFiles();
            if (entries == null) throw new IOException("list failed");
            for (File entry : entries) eraseOwnedMlsDirectory(entry);
        }
        if (!directory.delete() || directory.exists()) throw new IOException("erase failed");
    }

    /** 默认凭据加密非备份区域；不创建KeyStore包装钥，不要求逐次生物识别。 */
    private Map<String, Object> prepareMlsStorage(MethodCall call) throws Exception {
        Context context = applicationContext;
        if (context == null || context.isDeviceProtectedStorage()) throw new IOException("storage unavailable");
        UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
        if (users == null || !users.isUserUnlocked()) throw new IOException("storage locked");
        String user = call.argument("user_id");
        if (user == null || user.trim().isEmpty() || user.contains(":")) throw new IOException("invalid owner");
        byte[] bytes = user.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > 120) throw new IOException("invalid owner length");
        StringBuilder name = new StringBuilder();
        for (byte value : bytes) name.append(String.format(Locale.ROOT, "%02x", value & 255));
        // 规范系统提供的容器别名；聊天子目录仍须逐项拒绝符号链接。
        File root = migrateDirectory(context.getNoBackupFilesDir().getCanonicalFile(), "tatachat_sdk_mls", "chat_mls");
        File target = new File(root, name.toString());
        for (File directory : new File[]{root, target}) {
            if (!directory.getCanonicalPath().equals(directory.getAbsolutePath())) throw new IOException("symlink");
            if (!directory.exists() && !directory.mkdir()) throw new IOException("mkdir failed");
            if (!directory.isDirectory()) throw new IOException("not directory");
            Os.chmod(directory.getAbsolutePath(), 0700);
            if ((Os.stat(directory.getAbsolutePath()).st_mode & 0777) != 0700) throw new IOException("permissions failed");
        }
        Map<String, Object> result = new HashMap<>();
        // 平台只交付保护目录，身份首次准备由原生持久状态决定。
        result.put("path", target.getCanonicalPath());
        return result;
    }


    // 一次性升级只搬移原聊天目录；两个目录并存时拒绝合并，避免覆盖身份或历史。
    static File migrateDirectory(File base, String legacy, String current) throws Exception {
        File lock = new File(base, ".chat-storage-upgrade.lock");
        if (!lock.getCanonicalPath().equals(lock.getAbsolutePath())) throw new IOException("symlink");
        try (java.io.RandomAccessFile file = new java.io.RandomAccessFile(lock, "rw");
             java.nio.channels.FileLock held = file.getChannel().lock()) {
            Os.chmod(lock.getAbsolutePath(), 0600);
            File old = new File(base, legacy), target = new File(base, current);
            if (!old.getCanonicalPath().equals(old.getAbsolutePath()) || !target.getCanonicalPath().equals(target.getAbsolutePath())) throw new IOException("symlink");
            if (old.exists()) {
                if (target.exists() || !old.isDirectory() || !old.renameTo(target)) throw new IOException("chat upgrade conflict");
            }
            if (target.exists()) {
                File[] entries = target.listFiles();
                if (entries == null) throw new IOException("list failed");
                for (File entry : entries) {
                    String next = entry.getName().replace("tatachatsdk_chat", "chat").replace("tatachat_sdk_data", "chat_data");
                    if (!next.equals(entry.getName())) {
                        File to = new File(target, next);
                        if (to.exists() || !entry.getCanonicalPath().equals(entry.getAbsolutePath()) || !entry.renameTo(to)) throw new IOException("chat file upgrade conflict");
                    }
                }
            }
            return target;
        }
    }

}
