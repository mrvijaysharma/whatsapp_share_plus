package com.vijay_sharma.whatsapp_share_plus

import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * Unit tests for the parts of the Android implementation that do not need the
 * Android framework.
 *
 * Run from the command line:
 *   ./gradlew testDebugUnitTest
 * in the `example/android/` directory, or via Android Studio.
 */
internal class MimeTypesTest {

    @Test
    fun `a single type is used verbatim`() {
        assertEquals("image/jpeg", MimeTypes.narrowest(listOf("image/jpeg")))
    }

    @Test
    fun `identical types collapse to one`() {
        assertEquals(
            "image/png",
            MimeTypes.narrowest(listOf("image/png", "image/png")),
        )
    }

    @Test
    fun `types sharing a top level widen to a wildcard`() {
        assertEquals(
            "image/*",
            MimeTypes.narrowest(listOf("image/jpeg", "image/png", "image/webp")),
        )
    }

    @Test
    fun `a mixed set falls back to the catch-all`() {
        assertEquals(
            "*/*",
            MimeTypes.narrowest(listOf("image/jpeg", "application/pdf")),
        )
    }

    @Test
    fun `video and image do not collapse together`() {
        assertEquals(
            "*/*",
            MimeTypes.narrowest(listOf("image/jpeg", "video/mp4")),
        )
    }

    @Test
    fun `an empty list falls back to the catch-all`() {
        assertEquals("*/*", MimeTypes.narrowest(emptyList()))
    }

    @Test
    fun `blank entries are ignored`() {
        assertEquals(
            "image/jpeg",
            MimeTypes.narrowest(listOf("image/jpeg", "", "   ")),
        )
    }
}
