import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'whatsapp_share_plus_method_channel.dart';

abstract class WhatsappSharePlusPlatform extends PlatformInterface {
  WhatsappSharePlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static WhatsappSharePlusPlatform _instance = MethodChannelWhatsappSharePlus();

  static WhatsappSharePlusPlatform get instance => _instance;

  static set instance(WhatsappSharePlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> isWhatsappInstalled();

  Future<bool> isWhatsappBusinessInstalled();

  Future<bool?> shareToWhatsapp({
    required String text,
    String? phone,
  });

  Future<bool?> shareToWhatsappBusiness({
    required String text,
    String? phone,
  });

  Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  });

  Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  });
}
