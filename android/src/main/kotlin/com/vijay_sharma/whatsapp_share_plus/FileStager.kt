package com.vijay_sharma.whatsapp_share_plus

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.io.IOException
import java.util.concurrent.atomic.AtomicLong

/**
 * A file that has been copied into this plugin's cache and exposed through a
 * [FileProvider], ready to attach to a share intent.
 */
internal data class StagedFile(val uri: Uri, val mimeType: String)

/**
 * Copies the files a caller wants to share into a private cache directory and
 * hands back content URIs WhatsApp is allowed to read.
 *
 * The copy is not optional: a path handed in by the caller may live in a
 * directory WhatsApp has no permission to read, and granting read access to an
 * arbitrary location is not something a share should do.
 *
 * Each share gets its own session directory. WhatsApp reads the content URI
 * asynchronously, some time after the intent is delivered, so deleting files
 * eagerly at the start of the next share can pull a file out from under a share
 * that is still in flight. Instead, old sessions are pruned by age.
 */
internal class FileStager(private val context: Context) {

    private val root: File
        get() = File(context.cacheDir, SHARE_CACHE_DIRECTORY)

    private val authority: String
        get() = "${context.packageName}.$FILE_PROVIDER_SUFFIX"

    /**
     * Copies [files] into a fresh session directory.
     *
     * @param files the raw `ShareFile` maps sent from Dart.
     * @throws IOException if a source file is missing or cannot be copied.
     */
    fun stage(files: List<Map<*, *>>): List<StagedFile> {
        if (files.isEmpty()) return emptyList()

        val session = File(root, nextSessionName())
        if (!session.mkdirs() && !session.isDirectory) {
            throw IOException("Could not create the share cache directory.")
        }

        return copyInto(session, files).map { (destination, mimeType) ->
            StagedFile(
                uri = FileProvider.getUriForFile(context, authority, destination),
                mimeType = mimeType,
            )
        }
    }

    /**
     * Deletes session directories older than [maxAgeMillis].
     *
     * Called before staging a new share, which keeps the cache bounded without
     * touching files a share in flight may still be reading.
     */
    fun pruneOldSessions(maxAgeMillis: Long = DEFAULT_MAX_AGE_MILLIS) {
        val directory = root
        if (!directory.isDirectory) return
        val cutoff = System.currentTimeMillis() - maxAgeMillis
        directory.listFiles()?.forEach { session ->
            if (session.lastModified() < cutoff) {
                session.deleteRecursively()
            }
        }
    }

    private fun nextSessionName(): String {
        val stamp = System.currentTimeMillis().toString(36)
        return "$stamp-${sessionCounter.incrementAndGet()}"
    }

    internal companion object {
        /**
         * Copies [files] into [session], giving each attachment its own
         * numbered slot directory.
         *
         * The slotting is the whole point. Two files picked from different
         * folders routinely share a basename — IMG_0001.JPG from two albums —
         * and staging both directly into the session directory would make the
         * second overwrite the first, handing WhatsApp the same URI twice: one
         * attachment sent twice, the other silently dropped. A slot per index
         * keeps the visible file name intact, which matters because WhatsApp
         * shows it for documents.
         *
         * Separated from [stage] and kept free of [Context] so this rule can be
         * unit tested on the JVM without an Android device or a FileProvider.
         *
         * @return each staged file paired with its MIME type, in input order.
         * @throws IOException if a source file is missing or cannot be copied.
         */
        fun copyInto(session: File, files: List<Map<*, *>>): List<Pair<File, String>> =
            files.mapIndexed { index, raw ->
                val name = (raw["name"] as? String)?.takeIf { it.isNotBlank() }
                val mimeType = (raw["mimeType"] as? String) ?: DEFAULT_MIME_TYPE
                val bytes = raw["bytes"] as? ByteArray
                val path = raw["path"] as? String

                val slot = File(session, index.toString())
                if (!slot.mkdirs() && !slot.isDirectory) {
                    throw IOException("Could not create the share cache directory.")
                }

                val destination = when {
                    bytes != null -> {
                        val target = File(slot, sanitize(name ?: "attachment_$index"))
                        target.writeBytes(bytes)
                        target
                    }

                    path != null -> {
                        val source = File(path)
                        if (!source.exists()) {
                            throw FileNotFoundInShareException(path)
                        }
                        if (!source.canRead()) {
                            throw IOException("The file at $path cannot be read.")
                        }
                        val target = File(slot, sanitize(name ?: source.name))
                        source.copyTo(target, overwrite = true)
                        target
                    }

                    else -> throw IOException(
                        "A share file must carry either a path or bytes."
                    )
                }

                destination to mimeType
            }

        /**
         * Strips path separators so a caller-supplied name cannot escape the
         * slot directory.
         */
        fun sanitize(name: String): String {
            val cleaned = name.replace(Regex("[/\\\\]"), "_").trim()
            return cleaned.ifEmpty { "attachment" }
        }

        const val SHARE_CACHE_DIRECTORY = "whatsapp_share_plus"
        const val FILE_PROVIDER_SUFFIX = "whatsapp_share_plus.fileprovider"
        const val DEFAULT_MIME_TYPE = "application/octet-stream"

        /** Long enough for WhatsApp to finish reading, short enough to not hoard disk. */
        private const val DEFAULT_MAX_AGE_MILLIS = 60L * 60L * 1000L

        private val sessionCounter = AtomicLong(0)
    }
}

/** Raised when a caller passes a path that does not exist on disk. */
internal class FileNotFoundInShareException(val path: String) :
    IOException("Image file not found at path: $path")
