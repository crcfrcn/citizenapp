package com.crcfrcn.citizenapp

import android.system.Os
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.IOException
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** 使用生产迁移与保护函数；根目录只属于本用例，不接触正式聊天或钱包数据。 */
@RunWith(AndroidJUnit4::class)
class ChatStorageInstrumentedTest {
    @Test fun upgradePreservesDatabaseAndWipeMarkerBytes() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.cacheDir, "chat-upgrade-${UUID.randomUUID()}").canonicalFile.apply { mkdirs() }
        try {
            val legacy = File(root, "legacy").apply { mkdir() }
            val bytes = byteArrayOf(0, 1, 2, 127, -1)
            File(legacy, "tatachatsdk_chat.isar").writeBytes(bytes)
            File(legacy, ".tatachat_sdk_data_wipe.pending").writeText("pending\n")
            val migrated = ChatStorageChannel.migrateDirectory(root, "legacy", "chat_data")
            ChatStorageChannel.protectOwnedTree(migrated)
            assertArrayEquals(bytes, File(migrated, "chat.isar").readBytes())
            assertEquals("pending\n", File(migrated, ".chat_data_wipe.pending").readText())
            assertFalse(legacy.exists())
            assertEquals(0b111000000, Os.stat(migrated.path).st_mode and 0b111111111)
            assertEquals(0b110000000, Os.stat(File(migrated, "chat.isar").path).st_mode and 0b111111111)
            assertEquals(migrated, ChatStorageChannel.migrateDirectory(root, "legacy", "chat_data"))
        } finally { root.deleteRecursively() }
    }

    @Test fun upgradeRejectsConflictsAndLinksWithoutOverwritingEitherCopy() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.cacheDir, "chat-upgrade-${UUID.randomUUID()}").canonicalFile.apply { mkdirs() }
        try {
            File(root, "legacy").mkdir()
            File(root, "chat_data").mkdir()
            File(root, "legacy/state").writeText("legacy-state")
            File(root, "chat_data/state").writeText("current-state")
            assertThrows(IOException::class.java) { ChatStorageChannel.migrateDirectory(root, "legacy", "chat_data") }
            assertEquals("legacy-state", File(root, "legacy/state").readText())
            assertEquals("current-state", File(root, "chat_data/state").readText())
            File(root, "legacy").deleteRecursively()
            Os.symlink(File(root, "chat_data").path, File(root, "legacy").path)
            assertThrows(IOException::class.java) { ChatStorageChannel.migrateDirectory(root, "legacy", "chat_data") }
            File(root, "legacy").delete()
        } finally { root.deleteRecursively() }
    }
}
