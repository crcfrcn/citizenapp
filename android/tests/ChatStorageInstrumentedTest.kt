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

/** 使用生产保护函数；目录只属于本用例。 */
@RunWith(AndroidJUnit4::class)
class ChatStorageInstrumentedTest {
    @Test fun chatDirectoryProtectionPreservesBytesAndPermissions() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.cacheDir, "chat-protection-${UUID.randomUUID()}").canonicalFile.apply { mkdirs() }
        try {
            val bytes = byteArrayOf(0, 1, 2, 127, -1)
            val database = File(root, "chat.isar").apply { writeBytes(bytes) }
            ChatStorageChannel.protectOwnedTree(root)
            assertArrayEquals(bytes, database.readBytes())
            assertEquals(0b111000000, Os.stat(root.path).st_mode and 0b111111111)
            assertEquals(0b110000000, Os.stat(database.path).st_mode and 0b111111111)
        } finally { root.deleteRecursively() }
    }

    @Test fun chatDirectoryProtectionRejectsLinks() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.cacheDir, "chat-protection-${UUID.randomUUID()}").canonicalFile.apply { mkdirs() }
        try {
            val data = File(root, "chat_data").apply { mkdir() }
            val outside = File(root, "outside").apply { writeText("unchanged") }
            val link = File(data, "link")
            Os.symlink(outside.path, link.path)
            assertThrows(IOException::class.java) { ChatStorageChannel.protectOwnedTree(data) }
            assertEquals("unchanged", outside.readText())
            assertTrue(link.delete())
        } finally { root.deleteRecursively() }
    }
}
