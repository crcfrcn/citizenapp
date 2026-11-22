# 为Android设备测试保留目标应用共享库及目录保护接口的可调用符号。

-keep class androidx.tracing.Trace { *; }
-keep class kotlin.LazyKt** { *; }
-keep interface kotlin.Lazy { *; }
-keep interface kotlin.jvm.functions.Function0 { *; }
-keep class kotlin.jvm.internal.Intrinsics { *; }
-keep class kotlin.io.FilesKt** { *; }
-keep class kotlin.text.Charsets { *; }
# 目录保护回归调用正式实现。
-keep class com.crcfrcn.citizenapp.ChatStorageChannel {
    static void protectOwnedTree(java.io.File);
}
