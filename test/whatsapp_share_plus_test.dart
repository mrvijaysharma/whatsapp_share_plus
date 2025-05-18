import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_platform_interface.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWhatsappSharePlusPlatform
    with MockPlatformInterfaceMixin
    implements WhatsappSharePlusPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WhatsappSharePlusPlatform initialPlatform = WhatsappSharePlusPlatform.instance;

  test('$MethodChannelWhatsappSharePlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWhatsappSharePlus>());
  });

  test('getPlatformVersion', () async {
    WhatsappSharePlus whatsappSharePlusPlugin = WhatsappSharePlus();
    MockWhatsappSharePlusPlatform fakePlatform = MockWhatsappSharePlusPlatform();
    WhatsappSharePlusPlatform.instance = fakePlatform;

    expect(await whatsappSharePlusPlugin.getPlatformVersion(), '42');
  });
}
