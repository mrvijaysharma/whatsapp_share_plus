import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_platform_interface.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock platform that simulates WhatsApp being installed and sharing succeeding.
class MockWhatsappSharePlusPlatform
    with MockPlatformInterfaceMixin
    implements WhatsappSharePlusPlatform {
  @override
  Future<bool> isWhatsappInstalled() => Future.value(true);

  @override
  Future<bool> isWhatsappBusinessInstalled() => Future.value(false);

  @override
  Future<bool?> shareToWhatsapp({required String text, String? phone}) =>
      Future.value(true);

  @override
  Future<bool?> shareToWhatsappBusiness({required String text, String? phone}) =>
      Future.value(true);

  @override
  Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) =>
      Future.value(true);

  @override
  Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) =>
      Future.value(true);
}

void main() {
  final WhatsappSharePlusPlatform initialPlatform =
      WhatsappSharePlusPlatform.instance;

  test('MethodChannelWhatsappSharePlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWhatsappSharePlus>());
  });

  group('WhatsappSharePlus API', () {
    late MockWhatsappSharePlusPlatform fakePlatform;

    setUp(() {
      fakePlatform = MockWhatsappSharePlusPlatform();
      WhatsappSharePlusPlatform.instance = fakePlatform;
    });

    test('isWhatsappInstalled returns true', () async {
      expect(await WhatsappSharePlus.isWhatsappInstalled(), isTrue);
    });

    test('isWhatsappBusinessInstalled returns false', () async {
      expect(await WhatsappSharePlus.isWhatsappBusinessInstalled(), isFalse);
    });

    test('shareToWhatsapp returns true on success', () async {
      final result = await WhatsappSharePlus.shareToWhatsapp(text: 'Hello!');
      expect(result, isTrue);
    });

    test('shareToWhatsapp with phone returns true', () async {
      final result = await WhatsappSharePlus.shareToWhatsapp(
        text: 'Hello!',
        phone: '919876543210',
      );
      expect(result, isTrue);
    });

    test('shareToWhatsappBusiness returns true on success', () async {
      final result = await WhatsappSharePlus.shareToWhatsappBusiness(
        text: 'Hello Business!',
      );
      expect(result, isTrue);
    });

    test('shareImageToWhatsapp returns true on success', () async {
      final result = await WhatsappSharePlus.shareImageToWhatsapp(
        imagePath: '/path/to/image.jpg',
        text: 'Optional caption',
        phone: '919876543210',
      );
      expect(result, isTrue);
    });

    test('shareImageToWhatsapp with no text or phone returns true', () async {
      final result = await WhatsappSharePlus.shareImageToWhatsapp(
        imagePath: '/path/to/image.jpg',
      );
      expect(result, isTrue);
    });

    test('shareImageToWhatsappBusiness returns true on success', () async {
      final result = await WhatsappSharePlus.shareImageToWhatsappBusiness(
        imagePath: '/path/to/image.jpg',
      );
      expect(result, isTrue);
    });
  });
}
