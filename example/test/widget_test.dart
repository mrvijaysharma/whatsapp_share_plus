// A smoke test for the example app: it builds the widget tree with a stub
// platform in place, so nothing tries to reach a real WhatsApp install.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_platform_interface.dart';
import 'package:whatsapp_share_plus_example/main.dart';

/// Answers every platform call without touching a device.
class StubPlatform
    with MockPlatformInterfaceMixin
    implements WhatsappSharePlusPlatform {
  @override
  Future<bool> isInstalled(WhatsAppTarget target) async => true;

  @override
  Future<Set<WhatsAppTarget>> installedTargets() async =>
      <WhatsAppTarget>{WhatsAppTarget.standard};

  @override
  Future<ShareResult> share(ShareRequest request) async =>
      const ShareResult(status: ShareStatus.opened);

  @override
  Future<ShareResult> openChat(ShareRequest request) async =>
      const ShareResult(status: ShareStatus.opened);

  @override
  Future<WhatsAppDiagnostics> diagnose() async => const WhatsAppDiagnostics(
        platform: 'test',
        installedTargets: <WhatsAppTarget>{},
        issues: <DiagnosticIssue>[],
      );

  @override
  Future<bool> addStickerPack(StickerPack pack, WhatsAppTarget target) async =>
      true;

  @override
  Future<bool> isStickerPackSupported() async => true;

  @override
  Future<bool> isWhatsappInstalled() async => true;

  @override
  Future<bool> isWhatsappBusinessInstalled() async => false;

  @override
  Future<bool?> shareToWhatsapp({required String text, String? phone}) async =>
      true;

  @override
  Future<bool?> shareToWhatsappBusiness(
          {required String text, String? phone}) async =>
      true;

  @override
  Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) async =>
      true;

  @override
  Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) async =>
      true;
}

void main() {
  setUp(() {
    WhatsappSharePlusPlatform.instance = StubPlatform();
  });

  testWidgets('the example app builds and reports the installed app',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('whatsapp_share_plus'), findsOneWidget);
    expect(find.text('WhatsApp'), findsWidgets);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('the link preview reflects the message field',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    // The preview sits at the bottom of a ListView, so it is not built until
    // it scrolls into view.
    await tester.scrollUntilVisible(
      find.text('Shareable link'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final preview = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(preview.data, startsWith('https://wa.me/'));
    expect(preview.data, contains('Sent%20from%20whatsapp_share_plus'));
  });
}
