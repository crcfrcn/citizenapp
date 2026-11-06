# 仅由 AndroidTest 任务启用；不关闭 Release 优化或改变生产逻辑。
# Runner 及测试 APK 对目标 APK 中共享库的调用不能被完全内联或改名。
-keep class androidx.tracing.Trace { *; }
-keep class kotlin.LazyKt** { *; }
-keep interface kotlin.Lazy { *; }
-keep interface kotlin.jvm.functions.Function0 { *; }
-keep class kotlin.jvm.internal.Intrinsics { *; }
-keep class kotlin.io.FilesKt** { *; }
-keep class kotlin.text.Charsets { *; }
# 两项迁移回归只调用正式实现，不复制一份目录/权限算法。
-keep class com.crcfrcn.citizenapp.ChatStorageChannel {
    static java.io.File migrateDirectory(java.io.File, java.lang.String, java.lang.String);
    static void protectOwnedTree(java.io.File);
}
