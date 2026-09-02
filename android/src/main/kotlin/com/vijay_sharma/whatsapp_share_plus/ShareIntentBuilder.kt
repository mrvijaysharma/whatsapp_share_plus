package com.vijay_sharma.whatsapp_share_plus

import android.content.ClipData
import android.content.Intent
import android.net.Uri

/**
 * Builds the intent that hands a payload to WhatsApp.
 *
 * WhatsApp accepts several different intent shapes and picks a different
 * composer for each, so the shape is chosen from what is actually being sent
 * rather than from which API the caller happened to use.
 */
internal object ShareIntentBuilder {

    /**
     * Builds a share intent for [packageName].
     *
     * @param text message body, or the caption when a single media file is attached.
     * @param files files already staged into readable content URIs.
     * @param phone recipient in international digits-only form, if any.
     */
    fun build(
        text: String?,
        files: List<StagedFile>,
        phone: String?,
        packageName: String,
    ): Intent {
        val intent = when {
            files.isEmpty() -> textIntent(text, phone)
            files.size == 1 -> singleFileIntent(text, files.first(), phone)
            else -> multipleFilesIntent(text, files, phone)
        }

        intent.setPackage(packageName)
        if (files.isNotEmpty()) {
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return intent
    }

    /**
     * Builds an intent that opens a conversation without attaching anything.
     */
    fun openChatIntent(phone: String?, text: String?, packageName: String): Intent {
        return Intent(Intent.ACTION_VIEW, chatUri(phone, text)).setPackage(packageName)
    }

    /**
     * A text-only share.
     *
     * With a recipient, this goes through WhatsApp's own `wa.me` deep link,
     * which is the only documented way to address a specific contact and is far
     * more dependable across WhatsApp versions than the `jid` intent extra.
     */
    private fun textIntent(text: String?, phone: String?): Intent {
        if (!phone.isNullOrEmpty()) {
            return Intent(Intent.ACTION_VIEW, chatUri(phone, text))
        }
        return Intent(Intent.ACTION_SEND).apply {
            type = MimeTypes.TEXT
            putExtra(Intent.EXTRA_TEXT, text.orEmpty())
        }
    }

    private fun singleFileIntent(text: String?, file: StagedFile, phone: String?): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            type = file.mimeType
            putExtra(Intent.EXTRA_STREAM, file.uri)
            // WhatsApp reads EXTRA_TEXT as the media caption when a stream is present.
            if (!text.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            applyRecipient(phone)
            // ClipData carries the grant on devices that ignore the extra alone.
            clipData = ClipData.newRawUri(null, file.uri)
        }
    }

    private fun multipleFilesIntent(
        text: String?,
        files: List<StagedFile>,
        phone: String?,
    ): Intent {
        val uris = ArrayList<Uri>(files.map { it.uri })
        return Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = MimeTypes.narrowest(files.map { it.mimeType })
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            if (!text.isNullOrEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            applyRecipient(phone)
            clipData = ClipData.newRawUri(null, uris.first()).also { clip ->
                uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
            }
        }
    }

    /**
     * Addresses an attachment share at one contact.
     *
     * The `jid` extra is WhatsApp's own mechanism but has never been formally
     * documented, so it is applied as a hint: when WhatsApp honours it the
     * attachment goes straight to that chat, and when it does not the user sees
     * WhatsApp's contact picker with the attachment already loaded. Either way
     * the share succeeds.
     */
    private fun Intent.applyRecipient(phone: String?) {
        if (!phone.isNullOrEmpty()) {
            putExtra(WHATSAPP_JID_EXTRA, "$phone$WHATSAPP_JID_SUFFIX")
        }
    }

    private fun chatUri(phone: String?, text: String?): Uri {
        val builder = Uri.parse("https://wa.me/${phone.orEmpty()}").buildUpon()
        if (!text.isNullOrEmpty()) builder.appendQueryParameter("text", text)
        return builder.build()
    }

    private const val WHATSAPP_JID_EXTRA = "jid"
    private const val WHATSAPP_JID_SUFFIX = "@s.whatsapp.net"
}
