import groovy.json.JsonSlurper

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val flutterProjectRoot = System.getenv("CITIZENAPP_PROJECT_ROOT")
                ?.let { java.io.File(it) }
                ?: settingsDir.parentFile
            flutterProjectRoot.resolve("android/local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Flutter/Pub在本轮产品视图生成插件元数据；原件只读，所需修订仅进入本轮视图。
val flutterProjectRoot = System.getenv("CITIZENAPP_PROJECT_ROOT")
    ?.let { java.io.File(it) }
    ?: settingsDir.parentFile
val builtInKotlinViews = mapOf(
    "url_launcher_android" to "6.3.30",
    "video_player_android" to "2.9.5",
    "webview_flutter_android" to "4.12.0",
)
fun prepareBuiltInKotlinView(name: String, version: String, original: java.io.File): java.io.File {
    val source = original.canonicalFile
    require(source.isDirectory && source.parentFile.name == "$name-$version" && source.parentFile.parentFile.name == "pub.dev") {
        "插件来源与产品锁不一致：$name"
    }
    require(source.walkTopDown().none { java.nio.file.Files.isSymbolicLink(it.toPath()) }) { "插件原件含链接：$name" }
    val script = source.resolve("build.gradle.kts")
    require(script.isFile) { "插件脚本缺失：$name" }
    val needle = "    id(\"kotlin-android\")\n"
    val originalText = script.readText()
    require(originalText.indexOf(needle) >= 0 && originalText.indexOf(needle, originalText.indexOf(needle) + needle.length) < 0) {
        "插件 Kotlin 入口与固定修订不符：$name"
    }
    val expected = originalText.replace(needle, "    // AGP 9 内置 Kotlin，任务视图不重复应用 kotlin-android。\n")
    val view = flutterProjectRoot.resolve(".flutter-plugin-views/$name/android")
    if (!view.exists()) {
        require(view.parentFile.mkdirs() || view.parentFile.isDirectory) { "插件任务视图父目录无效：$name" }
        require(source.copyRecursively(view, overwrite = false)) { "插件任务视图复制失败：$name" }
        view.resolve("build.gradle.kts").writeText(expected)
    }
    require(view.isDirectory && view.canWrite()) { "插件任务视图无效：$name" }
    val sourceFiles = source.walkTopDown().filter { it.isFile }.map { it.relativeTo(source).path }.toSet()
    val viewFiles = view.walkTopDown().filter { it.isFile }.map { it.relativeTo(view).path }.toSet()
    require(sourceFiles == viewFiles && view.resolve("build.gradle.kts").readText() == expected) { "插件任务视图漂移：$name" }
    for (relative in sourceFiles - "build.gradle.kts") {
        require(source.resolve(relative).readBytes().contentEquals(view.resolve(relative).readBytes())) { "插件任务视图字节漂移：$name" }
    }
    return view
}
val flutterPlugins = flutterProjectRoot.resolve(".flutter-plugins-dependencies")
if (flutterPlugins.isFile) {
    val metadata = JsonSlurper().parse(flutterPlugins) as Map<*, *>
    val androidPlugins = (metadata["plugins"] as? Map<*, *>)?.get("android") as? List<*> ?: emptyList<Any>()
    androidPlugins.filterIsInstance<Map<*, *>>()
        .filter { it["native_build"] != false }
        .forEach { plugin ->
            val name = plugin["name"] as String
            include(":$name")
            val original = java.io.File(plugin["path"] as String, "android")
            project(":$name").projectDir = if (name in builtInKotlinViews) {
                prepareBuiltInKotlinView(name, builtInKotlinViews.getValue(name), original)
            } else if (name == "integration_test" && !original.canWrite()) {
                // Flutter SDK 是只读原件；Gradle 9 在本轮可写工程视图中配置插件。
                val sdk = java.util.Properties().apply {
                    flutterProjectRoot.resolve("android/local.properties").inputStream().use { load(it) }
                }.getProperty("flutter.sdk") ?: error("flutter.sdk 未配置")
                require(original.canonicalFile == java.io.File(sdk, "packages/integration_test/android").canonicalFile) {
                    "integration_test 来源不属于本轮 Flutter SDK"
                }
                flutterProjectRoot.resolve(".flutter-plugin-views/integration_test/android").also {
                    require(it.isDirectory && it.canWrite()) { "integration_test 本轮工程视图缺失" }
                }
            } else original
        }
}

include(":app")
