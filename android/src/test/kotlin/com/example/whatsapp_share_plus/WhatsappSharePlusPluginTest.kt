package com.vijay_sharma.whatsapp_share_plus

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import org.mockito.Mockito

/*
 * Unit tests for WhatsappSharePlusPlugin.
 *
 * Run from the command line:
 *   ./gradlew testDebugUnitTest
 * in the `example/android/` directory, or via Android Studio.
 */

internal class WhatsappSharePlusPluginTest {

  @Test
  fun onMethodCall_unknownMethod_returnsNotImplemented() {
    val plugin = WhatsappSharePlusPlugin()

    val call = MethodCall("unknownMethod", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).notImplemented()
  }
}
