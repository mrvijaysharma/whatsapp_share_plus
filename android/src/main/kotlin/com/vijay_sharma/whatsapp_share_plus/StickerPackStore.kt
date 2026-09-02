package com.vijay_sharma.whatsapp_share_plus

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException

/** One sticker as stored on disk. */
internal data class StoredSticker(
    val fileName: String,
    val emojis: List<String>,
    val accessibilityText: String?,
)

/** A sticker pack as stored on disk, ready to serve to WhatsApp. */
internal data class StoredStickerPack(
    val identifier: String,
    val name: String,
    val publisher: String,
    val trayFileName: String,
    val stickers: List<StoredSticker>,
    val animated: Boolean,
    val publisherEmail: String?,
    val publisherWebsite: String?,
    val privacyPolicyWebsite: String?,
    val licenseAgreementWebsite: String?,
    val version: Long,
)

/**
 * Persists sticker packs where [StickerContentProvider] can serve them.
 *
 * Packs live on disk rather than in memory because WhatsApp queries the content
 * provider on its own schedule, long after the share call returns and often
 * after this app's process has been killed. Android restarts the process just
 * to service the provider, at which point anything held only in a static field
 * is gone. Writing each pack to `filesDir` makes the provider survive that.
 */
internal object StickerPackStore {

    private const val ROOT_DIRECTORY = "whatsapp_share_plus_stickers"
    private const val MANIFEST_FILE = "pack.json"

    /** The directory holding every registered pack. */
    fun root(context: Context): File = File(context.filesDir, ROOT_DIRECTORY)

    /** The directory holding one pack's manifest and images. */
    fun directoryFor(context: Context, identifier: String): File =
        File(root(context), sanitize(identifier))

    /**
     * Writes [pack] — the raw map sent from Dart — to disk, replacing any
     * previous version of the same identifier.
     *
     * @return the stored representation.
     * @throws IOException if the pack cannot be written.
     */
    fun register(context: Context, pack: Map<*, *>): StoredStickerPack {
        val identifier = (pack["identifier"] as? String)?.takeIf { it.isNotBlank() }
            ?: throw IOException("A sticker pack requires a non-empty identifier.")

        val directory = directoryFor(context, identifier)
        if (directory.exists()) directory.deleteRecursively()
        if (!directory.mkdirs()) {
            throw IOException("Could not create the sticker pack directory.")
        }

        val trayFileName = writeImage(
            directory = directory,
            image = pack["trayImage"] as? Map<*, *>
                ?: throw IOException("A sticker pack requires a tray image."),
            fileName = "tray.webp",
        )

        val rawStickers = pack["stickers"] as? List<*> ?: emptyList<Any>()
        val stickers = rawStickers.mapIndexed { index, raw ->
            val sticker = raw as? Map<*, *>
                ?: throw IOException("Malformed sticker at index $index.")
            val image = sticker["image"] as? Map<*, *>
                ?: throw IOException("Sticker $index has no image.")
            StoredSticker(
                fileName = writeImage(directory, image, "sticker_$index.webp"),
                emojis = (sticker["emojis"] as? List<*>)
                    ?.filterIsInstance<String>()
                    .orEmpty(),
                accessibilityText = sticker["accessibilityText"] as? String,
            )
        }

        val stored = StoredStickerPack(
            identifier = identifier,
            name = pack["name"] as? String ?: identifier,
            publisher = pack["publisher"] as? String ?: "",
            trayFileName = trayFileName,
            stickers = stickers,
            animated = pack["animated"] as? Boolean ?: false,
            publisherEmail = pack["publisherEmail"] as? String,
            publisherWebsite = pack["publisherWebsite"] as? String,
            privacyPolicyWebsite = pack["privacyPolicyWebsite"] as? String,
            licenseAgreementWebsite = pack["licenseAgreementWebsite"] as? String,
            version = System.currentTimeMillis(),
        )

        File(directory, MANIFEST_FILE).writeText(stored.toJson().toString())
        return stored
    }

    /** Reads back one pack, or `null` if it was never registered. */
    fun read(context: Context, identifier: String): StoredStickerPack? {
        val manifest = File(directoryFor(context, identifier), MANIFEST_FILE)
        if (!manifest.isFile) return null
        return runCatching { fromJson(JSONObject(manifest.readText())) }.getOrNull()
    }

    /** Reads back every registered pack. */
    fun readAll(context: Context): List<StoredStickerPack> {
        val directories = root(context).listFiles() ?: return emptyList()
        return directories.mapNotNull { directory ->
            val manifest = File(directory, MANIFEST_FILE)
            if (!manifest.isFile) return@mapNotNull null
            runCatching { fromJson(JSONObject(manifest.readText())) }.getOrNull()
        }
    }

    /**
     * Resolves an image inside a pack, rejecting names that try to escape the
     * pack directory.
     */
    fun imageFile(context: Context, identifier: String, fileName: String): File? {
        val directory = directoryFor(context, identifier)
        val file = File(directory, sanitize(fileName))
        if (!file.isFile) return null
        // Defence in depth: confirm the resolved path really is inside the pack.
        val canonicalRoot = directory.canonicalPath
        return if (file.canonicalPath.startsWith(canonicalRoot)) file else null
    }

    /**
     * Writes one sticker image under a name this class chooses.
     *
     * The caller's own file name is deliberately ignored. Sticker file names
     * are never shown to anyone — WhatsApp addresses them through the content
     * provider — but they must be unique within a pack, and two stickers built
     * from `heart.webp` in different folders would otherwise collide, silently
     * overwriting one image and emitting a duplicate `sticker_file_name` that
     * makes WhatsApp reject the whole pack.
     */
    private fun writeImage(
        directory: File,
        image: Map<*, *>,
        fileName: String,
    ): String {
        val destination = File(directory, fileName)

        val bytes = image["bytes"] as? ByteArray
        if (bytes != null) {
            destination.writeBytes(bytes)
            return fileName
        }

        val path = image["path"] as? String
            ?: throw IOException("A sticker image needs either bytes or a path.")
        val source = File(path)
        if (!source.isFile) throw FileNotFoundInShareException(path)
        source.copyTo(destination, overwrite = true)
        return fileName
    }

    private fun sanitize(value: String): String =
        value.replace(Regex("[/\\\\]"), "_").replace("..", "_")

    private fun StoredStickerPack.toJson(): JSONObject = JSONObject().apply {
        put("identifier", identifier)
        put("name", name)
        put("publisher", publisher)
        put("trayFileName", trayFileName)
        put("animated", animated)
        put("version", version)
        publisherEmail?.let { put("publisherEmail", it) }
        publisherWebsite?.let { put("publisherWebsite", it) }
        privacyPolicyWebsite?.let { put("privacyPolicyWebsite", it) }
        licenseAgreementWebsite?.let { put("licenseAgreementWebsite", it) }
        put(
            "stickers",
            JSONArray().apply {
                stickers.forEach { sticker ->
                    put(
                        JSONObject().apply {
                            put("fileName", sticker.fileName)
                            put("emojis", JSONArray(sticker.emojis))
                            sticker.accessibilityText?.let { put("accessibilityText", it) }
                        },
                    )
                }
            },
        )
    }

    private fun fromJson(json: JSONObject): StoredStickerPack {
        val stickersJson = json.optJSONArray("stickers") ?: JSONArray()
        val stickers = (0 until stickersJson.length()).map { index ->
            val sticker = stickersJson.getJSONObject(index)
            val emojisJson = sticker.optJSONArray("emojis") ?: JSONArray()
            StoredSticker(
                fileName = sticker.getString("fileName"),
                emojis = (0 until emojisJson.length()).map(emojisJson::getString),
                accessibilityText = sticker.optString("accessibilityText").ifEmpty { null },
            )
        }
        return StoredStickerPack(
            identifier = json.getString("identifier"),
            name = json.optString("name"),
            publisher = json.optString("publisher"),
            trayFileName = json.optString("trayFileName"),
            stickers = stickers,
            animated = json.optBoolean("animated", false),
            publisherEmail = json.optString("publisherEmail").ifEmpty { null },
            publisherWebsite = json.optString("publisherWebsite").ifEmpty { null },
            privacyPolicyWebsite = json.optString("privacyPolicyWebsite").ifEmpty { null },
            licenseAgreementWebsite = json.optString("licenseAgreementWebsite").ifEmpty { null },
            version = json.optLong("version", 1L),
        )
    }
}
