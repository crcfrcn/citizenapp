plugins {
    id("com.android.application")
    // 当前原锁使用Flutter官方支持的KGP配置。
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}


android {
    namespace = "com.crcfrcn.citizenapp"
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    // 设备测试必须挂到正式 Release 变体，禁止为验收生成影子 Debug 应用。
    testBuildType = "release"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Google Play 永久应用标识与 Kotlin namespace 保持一致，禁止恢复不可用旧包名。
        applicationId = "com.crcfrcn.citizenapp"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk {
            // CitizenApp Android 唯一支持 64 位 ARM；禁止恢复其他 ABI。
            abiFilters.add("arm64-v8a")
        }
    }

    // 自动化由Gradle签名；本机只编译未签名Release，交给安装器签名。
    signingConfigs {
        if (System.getenv("GITHUB_ACTIONS") == "true") {
            create("release") {
                storeFile = file(System.getenv("CITIZENAPP_KEYSTORE") ?: error("缺少自动化签名输入"))
                storePassword = System.getenv("CITIZENAPP_STORE_PASSWORD")
                keyAlias = System.getenv("CITIZENAPP_KEY_ALIAS")
                keyPassword = System.getenv("CITIZENAPP_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            // Release 包不保留本地调试符号；CitizenSDK 原生库的构建与
            // 符号归档由 CitizenSDK 自己的产品流程负责。
        }
    }

    packaging {
        jniLibs {
            // 第三方插件可能携带非 ARM64 预编译库；打包阶段统一排除，确保 APK
            // 物理上只保留 defaultConfig 声明的 arm64-v8a。
            excludes.addAll(listOf("lib/armeabi*/**", "lib/x86/**", "lib/x86_64/**"))
        }
    }
}

dependencies {
    implementation("androidx.core:core:1.13.1")
    // 广场视频只走系统硬件 MediaCodec；Media3 提供受控的解码、缩放和 HEVC 编码帧管线。
    implementation("androidx.media3:media3-transformer:1.10.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}

// 统一使用Kotlin公开编译配置，与Java 17字节码保持一致。
kotlin {
    // 扁平受控输入在本轮工程中明确登记，避免Kotlin入口漏编。
    sourceSets.getByName("main").kotlin.setSrcDirs(listOf("src/main"))
    sourceSets.getByName("androidTest").kotlin.setSrcDirs(listOf("src/androidTest"))
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    // 调用方可以提供源码外Flutter工程视图；普通产品构建仍以本工程根为Flutter根。
    source = "../.."
}
