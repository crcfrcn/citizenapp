// 全部Android产品和SDK只使用AGP 9.0.1与Kotlin 2.2.20；根classpath不允许第二版本。
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // 通过公开DSL统一Android模块的编译API级别。
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.library") {
        // 固定CameraX 1.6.1的注解解析会读取此类型；仅给相机插件补齐官方编译依赖。
        if (project.name == "camera_android_camerax") {
            dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            compileSdk = 36
        }
    }
}

// 产品构建默认写系统临时目录；任何调用方都可提供源码外绝对目录，不依赖特定运维工具。
val citizenAppBuildValue = System.getenv("CITIZENAPP_BUILD_DIR")
    ?.takeIf { it.isNotBlank() }
    ?: "${System.getProperty("java.io.tmpdir")}/citizenapp/android"
val citizenAppBuildFile = rootProject.file(citizenAppBuildValue).canonicalFile
val citizenAppSourcePath = rootProject.projectDir.parentFile.canonicalFile.toPath()
require(citizenAppBuildFile.isAbsolute && !citizenAppBuildFile.toPath().startsWith(citizenAppSourcePath)) {
    "CITIZENAPP_BUILD_DIR必须是CitizenApp源码树外的绝对目录"
}
val newBuildDir: Directory = rootProject.layout.dir(rootProject.provider { citizenAppBuildFile }).get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
