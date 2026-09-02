package com.vijay_sharma.whatsapp_share_plus

import java.io.File
import java.nio.file.Files
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/*
 * Tests for the file staging rule, exercised through FileStager.copyInto,
 * which is deliberately free of any Android Context so it runs on the JVM.
 *
 * Run from the command line:
 *   ./gradlew :whatsapp_share_plus:testDebugUnitTest
 * in the `example/android/` directory.
 */
internal class FileStagerTest {

    private val session: File = Files.createTempDirectory("stager-test").toFile()

    @AfterTest
    fun cleanUp() {
        session.deleteRecursively()
    }

    private fun sourceFile(name: String, contents: String): File {
        val directory = Files.createTempDirectory("stager-src").toFile()
        return File(directory, name).apply { writeText(contents) }
    }

    @Test
    fun `two attachments sharing a basename keep separate files`() {
        // The regression this guards: picking IMG_0001.JPG from two different
        // albums used to stage both to one path, so WhatsApp received the same
        // URI twice — one photo sent twice, the other silently dropped.
        val first = sourceFile("IMG_0001.JPG", "first")
        val second = sourceFile("IMG_0001.JPG", "second")

        val staged = FileStager.copyInto(
            session,
            listOf(
                mapOf("path" to first.path, "name" to "IMG_0001.JPG", "mimeType" to "image/jpeg"),
                mapOf("path" to second.path, "name" to "IMG_0001.JPG", "mimeType" to "image/jpeg"),
            ),
        )

        assertEquals(2, staged.size)
        assertEquals(
            2,
            staged.map { it.first.canonicalPath }.toSet().size,
            "both attachments resolved to the same path",
        )
        assertEquals("first", staged[0].first.readText())
        assertEquals("second", staged[1].first.readText())
    }

    @Test
    fun `the visible file name is preserved`() {
        // WhatsApp shows this name for documents, so slotting must not rename.
        val source = sourceFile("Quarterly Report.pdf", "%PDF")

        val staged = FileStager.copyInto(
            session,
            listOf(
                mapOf(
                    "path" to source.path,
                    "name" to "Quarterly Report.pdf",
                    "mimeType" to "application/pdf",
                ),
            ),
        )

        assertEquals("Quarterly Report.pdf", staged.single().first.name)
        assertEquals("application/pdf", staged.single().second)
    }

    @Test
    fun `byte-backed attachments are slotted too`() {
        val staged = FileStager.copyInto(
            session,
            listOf(
                mapOf("bytes" to "one".toByteArray(), "name" to "note.txt"),
                mapOf("bytes" to "two".toByteArray(), "name" to "note.txt"),
            ),
        )

        assertEquals(2, staged.map { it.first.canonicalPath }.toSet().size)
        assertEquals("one", staged[0].first.readText())
        assertEquals("two", staged[1].first.readText())
    }

    @Test
    fun `a name cannot escape its slot directory`() {
        val staged = FileStager.copyInto(
            session,
            listOf(mapOf("bytes" to "x".toByteArray(), "name" to "../../escaped.txt")),
        )

        val destination = staged.single().first
        assertTrue(
            destination.canonicalPath.startsWith(session.canonicalPath),
            "staged file escaped the session directory: ${destination.canonicalPath}",
        )
        assertEquals(false, File(session.parentFile, "escaped.txt").exists())
    }

    @Test
    fun `an unnamed attachment still gets a distinct file`() {
        val staged = FileStager.copyInto(
            session,
            listOf(
                mapOf("bytes" to "a".toByteArray()),
                mapOf("bytes" to "b".toByteArray()),
            ),
        )

        assertEquals(2, staged.map { it.first.canonicalPath }.toSet().size)
    }

    @Test
    fun `a missing source is reported as not found`() {
        assertFailsWith<FileNotFoundInShareException> {
            FileStager.copyInto(
                session,
                listOf(mapOf("path" to "/does/not/exist.png", "name" to "exist.png")),
            )
        }
    }

    @Test
    fun `an attachment carrying neither a path nor bytes is rejected`() {
        assertFailsWith<java.io.IOException> {
            FileStager.copyInto(session, listOf(mapOf("name" to "orphan.txt")))
        }
    }

    @Test
    fun `the default mime type is applied when none is given`() {
        val staged = FileStager.copyInto(
            session,
            listOf(mapOf("bytes" to "x".toByteArray(), "name" to "blob.bin")),
        )

        assertEquals(FileStager.DEFAULT_MIME_TYPE, staged.single().second)
    }
}
