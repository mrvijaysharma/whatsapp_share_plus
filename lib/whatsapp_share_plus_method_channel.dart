import 'package:flutter/services.dart';

import 'whatsapp_share_plus_platform_interface.dart';

class MethodChannelWhatsappSharePlus extends WhatsappSharePlusPlatform {
  final MethodChannel _channel = const MethodChannel('whatsapp_share_plus');

  @override
  Future<bool> isWhatsappInstalled() async {
    final bool? result = await _channel.invokeMethod('isWhatsappInstalled');
    return result ?? false;
  }

  @override
  Future<bool> isWhatsappBusinessInstalled() async {
    final bool? result = await _channel.invokeMethod('isWhatsappBusinessInstalled');
    return result ?? false;
  }

  @override
  Future<bool?> shareToWhatsapp({
    required String text,
    String? phone,
  }) async {
    final bool? result = await _channel.invokeMethod('shareToWhatsapp', {
      'text': text,
      if (phone != null) 'phone': phone,
    });
    return result;
  }

  @override
  Future<bool?> shareToWhatsappBusiness({
    required String text,
    String? phone,
  }) async {
    final bool? result = await _channel.invokeMethod('shareToWhatsappBusiness', {
      'text': text,
      if (phone != null) 'phone': phone,
    });
    return result;
  }

  @override
  Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) async {
    final bool? result = await _channel.invokeMethod('shareToWhatsapp', {
      'imagePath': imagePath,
      if (text != null) 'text': text,
      if (phone != null) 'phone': phone,
    });
    return result;
  }

  @override
  Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) async {
    final bool? result = await _channel.invokeMethod('shareToWhatsappBusiness', {
      'imagePath': imagePath,
      if (text != null) 'text': text,
      if (phone != null) 'phone': phone,
    });
    return result;
  }
}
