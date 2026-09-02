package com.vijay_sharma.whatsapp_share_plus

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.UriMatcher
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.content.res.AssetFileDescriptor
import java.io.File

/**
 * Serves this app's sticker packs to WhatsApp.
 *
 * WhatsApp does not accept sticker files directly. Instead the publishing app
 * exposes a content provider at a fixed set of paths, WhatsApp queries it, and
 * the user confirms the install. This class implements that contract:
 *
 * - `content://<authority>/metadata` — every pack this app publishes
 * - `content://<authority>/metadata/<identifier>` — one pack
 * - `content://<authority>/stickers/<identifier>` — the stickers in a pack
 * - `content://<authority>/stickers_asset/<identifier>/<file>` — one image
 *
 * The provider is exported and guarded by WhatsApp's own read permission, so
 * only WhatsApp can read it. Pack contents come from [StickerPackStore], which
 * keeps them on disk so this provider still works when Android starts the
 * process solely to answer a query.
 */
class StickerContentProvider : ContentProvider() {

    private lateinit var authority: String
    private val matcher = UriMatcher(UriMatcher.NO_MATCH)

    override fun attachInfo(context: Context?, info: ProviderInfo?) {
        super.attachInfo(context, info)
        authority = info?.authority
            ?: error("StickerContentProvider requires an authority in the manifest.")
        matcher.addURI(authority, METADATA, CODE_METADATA_ALL)
        matcher.addURI(authority, "$METADATA/*", CODE_METADATA_ONE)
        matcher.addURI(authority, "$STICKERS/*", CODE_STICKERS)
        matcher.addURI(authority, "$STICKERS_ASSET/*/*", CODE_ASSET)
    }

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? {
        val context = context ?: return null
        return when (matcher.match(uri)) {
            CODE_METADATA_ALL -> metadataCursor(uri, StickerPackStore.readAll(context))
            CODE_METADATA_ONE -> {
                val identifier = uri.lastPathSegment ?: return null
                val pack = StickerPackStore.read(context, identifier) ?: return null
                metadataCursor(uri, listOf(pack))
            }

            CODE_STICKERS -> {
                val identifier = uri.lastPathSegment ?: return null
                val pack = StickerPackStore.read(context, identifier) ?: return null
                stickersCursor(uri, pack)
            }

            else -> null
        }
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        if (matcher.match(uri) != CODE_ASSET) return null
        val context = context ?: return null

        val segments = uri.pathSegments
        if (segments.size < 3) return null
        val identifier = segments[segments.size - 2]
        val fileName = segments.last()

        val file: File = StickerPackStore.imageFile(context, identifier, fileName)
            ?: return null

        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        return AssetFileDescriptor(descriptor, 0, AssetFileDescriptor.UNKNOWN_LENGTH)
    }

    override fun getType(uri: Uri): String? = when (matcher.match(uri)) {
        CODE_METADATA_ALL -> "vnd.android.cursor.dir/vnd.$authority.$METADATA"
        CODE_METADATA_ONE -> "vnd.android.cursor.item/vnd.$authority.$METADATA"
        CODE_STICKERS -> "vnd.android.cursor.dir/vnd.$authority.$STICKERS"
        CODE_ASSET -> "image/webp"
        else -> null
    }

    /** Read-only by contract: WhatsApp never writes through this provider. */
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    private fun metadataCursor(uri: Uri, packs: List<StoredStickerPack>): Cursor {
        val cursor = MatrixCursor(METADATA_COLUMNS)
        packs.forEach { pack ->
            cursor.addRow(
                arrayOf<Any?>(
                    pack.identifier,
                    pack.name,
                    pack.publisher,
                    pack.trayFileName,
                    "", // Play Store link: the publishing app supplies this, not the plugin.
                    "", // App Store link, likewise.
                    pack.publisherEmail.orEmpty(),
                    pack.publisherWebsite.orEmpty(),
                    pack.privacyPolicyWebsite.orEmpty(),
                    pack.licenseAgreementWebsite.orEmpty(),
                    pack.version.toString(),
                    0, // "whitelisted" is decided by WhatsApp, never asserted here.
                    if (pack.animated) 1 else 0,
                ),
            )
        }
        cursor.setNotificationUri(context?.contentResolver, uri)
        return cursor
    }

    private fun stickersCursor(uri: Uri, pack: StoredStickerPack): Cursor {
        val cursor = MatrixCursor(STICKER_COLUMNS)
        pack.stickers.forEach { sticker ->
            cursor.addRow(
                arrayOf<Any?>(
                    sticker.fileName,
                    sticker.emojis.joinToString(","),
                    sticker.accessibilityText.orEmpty(),
                ),
            )
        }
        cursor.setNotificationUri(context?.contentResolver, uri)
        return cursor
    }

    internal companion object {
        const val METADATA = "metadata"
        const val STICKERS = "stickers"
        const val STICKERS_ASSET = "stickers_asset"

        private const val CODE_METADATA_ALL = 1
        private const val CODE_METADATA_ONE = 2
        private const val CODE_STICKERS = 3
        private const val CODE_ASSET = 4

        /** Column names and order fixed by WhatsApp's sticker pack contract. */
        private val METADATA_COLUMNS = arrayOf(
            "sticker_pack_identifier",
            "sticker_pack_name",
            "sticker_pack_publisher",
            "sticker_pack_icon",
            "android_play_store_link",
            "ios_app_download_link",
            "sticker_pack_publisher_email",
            "sticker_pack_publisher_website",
            "sticker_pack_privacy_policy_website",
            "sticker_pack_license_agreement_website",
            "image_data_version",
            "whitelisted",
            "animated_sticker_pack",
        )

        private val STICKER_COLUMNS = arrayOf(
            "sticker_file_name",
            "sticker_emoji",
            "sticker_accessibility_text",
        )

        /** The provider authority for [packageName]. */
        fun authorityFor(packageName: String): String =
            "$packageName.whatsapp_share_plus.stickercontentprovider"
    }
}
