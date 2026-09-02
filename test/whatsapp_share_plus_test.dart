import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_method_channel.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_platform_interface.dart';

/// A platform double that records what it was asked to do.
class FakeWhatsappSharePlusPlatform
    with MockPlatformInterfaceMixin
    implements WhatsappSharePlusPlatform {
  ShareRequest? lastShare;
  ShareRequest? lastOpenChat;
  StickerPack? lastStickerPack;
  WhatsAppTarget? lastStickerTarget;

  Set<WhatsAppTarget> installed = <WhatsAppTarget>{WhatsAppTarget.standard};

  @override
  Future<bool> isInstalled(WhatsAppTarget target) async =>
      installed.contains(target);

  @override
  Future<Set<WhatsAppTarget>> installedTargets() async => installed;

  @override
  Future<ShareResult> share(ShareRequest request) async {
    lastShare = request;
    return ShareResult(status: ShareStatus.opened, target: request.target);
  }

  @override
  Future<ShareResult> openChat(ShareRequest request) async {
    lastOpenChat = request;
    return ShareResult(status: ShareStatus.opened, target: request.target);
  }

  @override
  Future<WhatsAppDiagnostics> diagnose() async => const WhatsAppDiagnostics(
        platform: 'test',
        installedTargets: <WhatsAppTarget>{},
        issues: <DiagnosticIssue>[],
      );

  @override
  Future<bool> addStickerPack(StickerPack pack, WhatsAppTarget target) async {
    lastStickerPack = pack;
    lastStickerTarget = target;
    return true;
  }

  @override
  Future<bool> isStickerPackSupported() async => true;

  // The 1.x surface is implemented by the platform interface itself; a double
  // using `implements` has to restate it.
  @override
  Future<bool> isWhatsappInstalled() => isInstalled(WhatsAppTarget.standard);

  @override
  Future<bool> isWhatsappBusinessInstalled() =>
      isInstalled(WhatsAppTarget.business);

  @override
  Future<bool?> shareToWhatsapp({required String text, String? phone}) async =>
      (await share(ShareRequest(text: text, phone: phone))).isSuccess;

  @override
  Future<bool?> shareToWhatsappBusiness({
    required String text,
    String? phone,
  }) async =>
      (await share(ShareRequest(
        text: text,
        phone: phone,
        target: WhatsAppTarget.business,
      )))
          .isSuccess;

  @override
  Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) async =>
      (await share(ShareRequest(
        text: text,
        phone: phone,
        files: <ShareFile>[ShareFile.fromPath(imagePath)],
      )))
          .isSuccess;

  @override
  Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) async =>
      (await share(ShareRequest(
        text: text,
        phone: phone,
        target: WhatsAppTarget.business,
        files: <ShareFile>[ShareFile.fromPath(imagePath)],
      )))
          .isSuccess;
}

void main() {
  test('the method channel implementation is the default', () {
    expect(
      WhatsappSharePlusPlatform.instance,
      isInstanceOf<MethodChannelWhatsappSharePlus>(),
    );
  });

  group('WhatsAppShare', () {
    late FakeWhatsappSharePlusPlatform platform;

    setUp(() {
      platform = FakeWhatsappSharePlusPlatform();
      WhatsappSharePlusPlatform.instance = platform;
    });

    test('reports whether a target is installed', () async {
      expect(await WhatsAppShare.isInstalled(), isTrue);
      expect(
        await WhatsAppShare.isInstalled(target: WhatsAppTarget.business),
        isFalse,
      );
    });

    test('lists every installed target', () async {
      platform.installed = WhatsAppTarget.values.toSet();
      expect(await WhatsAppShare.installedTargets(), hasLength(2));
    });

    test('forwards text, files, and target to the platform', () async {
      await WhatsAppShare.share(
        text: 'Hello',
        files: <ShareFile>[ShareFile.fromPath('/tmp/a.png')],
        target: WhatsAppTarget.business,
      );

      expect(platform.lastShare!.text, 'Hello');
      expect(platform.lastShare!.files, hasLength(1));
      expect(platform.lastShare!.target, WhatsAppTarget.business);
    });

    test('rejects a share with neither text nor files', () async {
      expect(
        () => WhatsAppShare.share(),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });

    test('rejects whitespace-only text as an empty payload', () async {
      expect(
        () => WhatsAppShare.share(text: '   '),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });

    test('rejects a phone number that cannot be international', () async {
      expect(
        () => WhatsAppShare.share(text: 'Hi', phone: '12'),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });

    test('accepts a phone number written with punctuation', () async {
      await WhatsAppShare.share(text: 'Hi', phone: '+91 98765-43210');
      expect(platform.lastShare!.phone, '+91 98765-43210');
    });

    test('openChat requires a usable number', () async {
      expect(
        () => WhatsAppShare.openChat(phone: 'not a number'),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });

    test('openChat forwards to the platform', () async {
      await WhatsAppShare.openChat(phone: '919876543210', text: 'Hi');
      expect(platform.lastOpenChat!.phone, '919876543210');
      expect(platform.lastOpenChat!.text, 'Hi');
    });

    test('addStickerPack passes the chosen target through', () async {
      final pack = StickerPack(
        identifier: 'pack',
        name: 'Pack',
        publisher: 'Publisher',
        trayImage: ShareFile.fromPath('/tmp/tray.png'),
        stickers: const <Sticker>[],
      );

      await WhatsAppShare.addStickerPack(
        pack,
        target: WhatsAppTarget.business,
      );

      expect(platform.lastStickerPack, same(pack));
      expect(platform.lastStickerTarget, WhatsAppTarget.business);
    });
  });

  group('the 1.x API', () {
    late FakeWhatsappSharePlusPlatform platform;

    setUp(() {
      platform = FakeWhatsappSharePlusPlatform();
      WhatsappSharePlusPlatform.instance = platform;
    });

    test('shareToWhatsapp still shares text', () async {
      // ignore: deprecated_member_use_from_same_package
      final result = await WhatsappSharePlus.shareToWhatsapp(text: 'Hello');
      expect(result, isTrue);
      expect(platform.lastShare!.text, 'Hello');
      expect(platform.lastShare!.target, WhatsAppTarget.standard);
    });

    test('shareImageToWhatsappBusiness still targets Business', () async {
      // ignore: deprecated_member_use_from_same_package
      final result = await WhatsappSharePlus.shareImageToWhatsappBusiness(
        imagePath: '/tmp/photo.jpg',
        text: 'Caption',
      );
      expect(result, isTrue);
      expect(platform.lastShare!.target, WhatsAppTarget.business);
      expect(platform.lastShare!.files.single.path, '/tmp/photo.jpg');
    });

    test('isWhatsappInstalled still answers', () async {
      // ignore: deprecated_member_use_from_same_package
      expect(await WhatsappSharePlus.isWhatsappInstalled(), isTrue);
      // ignore: deprecated_member_use_from_same_package
      expect(await WhatsappSharePlus.isWhatsappBusinessInstalled(), isFalse);
    });
  });
}
