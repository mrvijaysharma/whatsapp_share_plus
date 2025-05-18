import 'whatsapp_share_plus_platform_interface.dart';

class WhatsappSharePlus {
  /// Check if WhatsApp is installed
  static Future<bool> isWhatsappInstalled() {
    return WhatsappSharePlusPlatform.instance.isWhatsappInstalled();
  }

  /// Check if WhatsApp Business is installed
  static Future<bool> isWhatsappBusinessInstalled() {
    return WhatsappSharePlusPlatform.instance.isWhatsappBusinessInstalled();
  }

  /// Share text message to WhatsApp
  static Future<bool?> shareToWhatsapp({
    required String text,
    String? phone,
  }) {
    return WhatsappSharePlusPlatform.instance.shareToWhatsapp(
      text: text,
      phone: phone,
    );
  }

  /// Share text message to WhatsApp Business
  static Future<bool?> shareToWhatsappBusiness({
    required String text,
    String? phone,
  }) {
    return WhatsappSharePlusPlatform.instance.shareToWhatsappBusiness(
      text: text,
      phone: phone,
    );
  }

  /// Share image with optional text and phone to WhatsApp
  static Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) {
    return WhatsappSharePlusPlatform.instance.shareImageToWhatsapp(
      imagePath: imagePath,
      text: text,
      phone: phone,
    );
  }

  /// Share image with optional text and phone to WhatsApp Business
  static Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) {
    return WhatsappSharePlusPlatform.instance.shareImageToWhatsappBusiness(
      imagePath: imagePath,
      text: text,
      phone: phone,
    );
  }
}
