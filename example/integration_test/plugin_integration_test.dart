// Integration tests run on a real device or simulator, where the plugin's
// native side is actually registered.
//
// Sharing itself cannot be asserted here: every share hands control to another
// app, which a test cannot drive or come back from. What these tests do check
// is that the channel is wired up and that the plugin answers the questions
// that do not leave the app.
//
// Run with: flutter test integration_test

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('install checks reach the platform and return a bool',
      (WidgetTester tester) async {
    // The value depends on the device; that it answers at all is the point.
    expect(await WhatsAppShare.isInstalled(), isA<bool>());
    expect(
      await WhatsAppShare.isInstalled(target: WhatsAppTarget.business),
      isA<bool>(),
    );
  });

  testWidgets('installedTargets agrees with the individual checks',
      (WidgetTester tester) async {
    final targets = await WhatsAppShare.installedTargets();
    for (final target in WhatsAppTarget.values) {
      expect(
        targets.contains(target),
        await WhatsAppShare.isInstalled(target: target),
        reason: '${target.displayName} was reported inconsistently',
      );
    }
  });

  testWidgets('diagnostics come back describing this platform',
      (WidgetTester tester) async {
    final report = await WhatsAppShare.diagnose();
    expect(report.platform, isNotEmpty);
    expect(report.platform, isNot('unknown'));
  });

  testWidgets('an empty share is rejected before it reaches the platform',
      (WidgetTester tester) async {
    await expectLater(
      WhatsAppShare.share(),
      throwsA(isA<InvalidShareArgumentException>()),
    );
  });

  testWidgets('a malformed phone number is rejected',
      (WidgetTester tester) async {
    await expectLater(
      WhatsAppShare.openChat(phone: '123'),
      throwsA(isA<InvalidShareArgumentException>()),
    );
  });

  testWidgets('sticker support is reported for this platform',
      (WidgetTester tester) async {
    expect(await WhatsAppShare.isStickerPackSupported(), isA<bool>());
  });
}
