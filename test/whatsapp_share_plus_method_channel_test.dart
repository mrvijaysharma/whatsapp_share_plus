import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelWhatsappSharePlus platform =
      MethodChannelWhatsappSharePlus();
  const MethodChannel channel = MethodChannel('whatsapp_share_plus');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isWhatsappInstalled':
          return true;
        case 'isWhatsappBusinessInstalled':
          return false;
        case 'shareToWhatsapp':
        case 'shareToWhatsappBusiness':
        case 'shareImageToWhatsapp':
        case 'shareImageToWhatsappBusiness':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isWhatsappInstalled returns bool', () async {
    expect(await platform.isWhatsappInstalled(), isTrue);
  });

  test('isWhatsappBusinessInstalled returns bool', () async {
    expect(await platform.isWhatsappBusinessInstalled(), isFalse);
  });

  test('shareToWhatsapp invokes correct method and returns bool', () async {
    final result = await platform.shareToWhatsapp(text: 'Hello');
    expect(result, isTrue);
  });

  test('shareToWhatsapp with phone invokes correct method', () async {
    final result =
        await platform.shareToWhatsapp(text: 'Hello', phone: '919876543210');
    expect(result, isTrue);
  });

  test('shareToWhatsappBusiness invokes correct method', () async {
    final result =
        await platform.shareToWhatsappBusiness(text: 'Hello Business');
    expect(result, isTrue);
  });

  test('shareImageToWhatsapp invokes shareImageToWhatsapp method', () async {
    final result = await platform.shareImageToWhatsapp(
      imagePath: '/path/to/image.jpg',
      text: 'Caption',
      phone: '919876543210',
    );
    expect(result, isTrue);
  });

  test('shareImageToWhatsappBusiness invokes shareImageToWhatsappBusiness method',
      () async {
    final result = await platform.shareImageToWhatsappBusiness(
      imagePath: '/path/to/image.jpg',
    );
    expect(result, isTrue);
  });
}
