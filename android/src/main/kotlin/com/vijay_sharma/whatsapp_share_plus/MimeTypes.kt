package com.vijay_sharma.whatsapp_share_plus

/**
 * MIME type reasoning for share intents.
 *
 * Kept free of Android imports so it can be exercised by plain JVM unit tests;
 * everything here is string manipulation.
 */
internal object MimeTypes {

    const val ANY = "*/*"
    const val TEXT = "text/plain"
    const val OCTET_STREAM = "application/octet-stream"

    /**
     * The narrowest type that covers every entry in [mimeTypes].
     *
     * WhatsApp picks its composer from the intent type, so this matters: a set
     * of photos sent as an image wildcard opens the gallery composer, while the
     * same set sent as the catch-all opens the document picker.
     *
     * - One distinct type is used verbatim.
     * - Several types sharing a top level collapse to that level's wildcard,
     *   such as [ANY] for a mixed set or an image wildcard for photos.
     * - A genuinely mixed set falls back to [ANY].
     *
     * Note for maintainers: Kotlin nests block comments, so a literal
     * slash-star sequence inside a doc comment opens a nested comment and
     * swallows the rest of the file. Wildcard types are spelled out in prose
     * here for that reason.
     */
    fun narrowest(mimeTypes: List<String>): String {
        val distinct = mimeTypes.filter { it.isNotBlank() }.toSet()
        if (distinct.isEmpty()) return ANY
        if (distinct.size == 1) return distinct.first()

        val topLevels = distinct.map { it.substringBefore('/') }.toSet()
        return if (topLevels.size == 1) "${topLevels.first()}/*" else ANY
    }
}
