import 'package:flutter/services.dart';

import '../links/phone_number.dart';
import '../models/diagnostics.dart';
import '../models/exceptions.dart';
import '../models/share_request.dart';
import '../models/share_result.dart';
import '../models/sticker_pack.dart';
import '../models/whatsapp_target.dart';
import 'whatsapp_share_platform.dart';

/// The default platform implementation, backed by a method channel.
///
/// Used on Android, iOS, macOS, Windows, and Linux. The web implementation is
/// pure Dart and registers itself in place of this one.
class MethodChannelWhatsappSharePlus extends WhatsappSharePlusPlatform {
  /// The channel this implementation talks over.
  ///
  /// Visible for testing.
  final MethodChannel channel = const MethodChannel('whatsapp_share_plus');

  @override
  Future<bool> isInstalled(WhatsAppTarget target) async {
    final result = await _invoke<bool>(
      'isInstalled',
      <String, Object?>{'target': target.wireName},
    );
    return result ?? false;
  }

  @override
  Future<Set<WhatsAppTarget>> installedTargets() async {
    final result = await _invoke<List<Object?>>('installedTargets');
    if (result == null) return const <WhatsAppTarget>{};
    return result.whereType<String>().map(WhatsAppTarget.fromWireName).toSet();
  }

  @override
  Future<ShareResult> share(ShareRequest request) async {
    request.validate();
    final payload = request.toMap(
      normalizedPhone: request.phone == null
          ? null
          : WhatsAppPhoneNumber.parse(request.phone!),
    );
    final result = await _invoke<Map<Object?, Object?>>('share', payload);
    return _resultFrom(result, request.target);
  }

  @override
  Future<ShareResult> openChat(ShareRequest request) async {
    final payload = request.toMap(
      normalizedPhone: request.phone == null
          ? null
          : WhatsAppPhoneNumber.parse(request.phone!),
    );
    final result = await _invoke<Map<Object?, Object?>>('openChat', payload);
    return _resultFrom(result, request.target);
  }

  @override
  Future<WhatsAppDiagnostics> diagnose() async {
    final result = await _invoke<Map<Object?, Object?>>('diagnose');
    if (result == null) {
      return const WhatsAppDiagnostics(
        platform: 'unknown',
        installedTargets: <WhatsAppTarget>{},
        issues: <DiagnosticIssue>[],
      );
    }
    return WhatsAppDiagnostics.fromMap(result);
  }

  @override
  Future<bool> addStickerPack(StickerPack pack, WhatsAppTarget target) async {
    await pack.validateOrThrow();
    final result = await _invoke<bool>('addStickerPack', <String, Object?>{
      ...pack.toMap(),
      'target': target.wireName,
    });
    return result ?? false;
  }

  @override
  Future<bool> isStickerPackSupported() async {
    final result = await _invoke<bool>('isStickerPackSupported');
    return result ?? false;
  }

  ShareResult _resultFrom(Map<Object?, Object?>? raw, WhatsAppTarget target) {
    if (raw == null) {
      return ShareResult(status: ShareStatus.opened, target: target);
    }
    return ShareResult.fromMap(raw);
  }

  /// Invokes [method] and converts platform errors into this package's typed
  /// exceptions, so callers never have to match on raw string error codes.
  Future<T?> _invoke<T>(String method,
      [Map<String, Object?>? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw _translate(error, arguments);
    } on MissingPluginException {
      throw UnsupportedShareException(
        'whatsapp_share_plus has no implementation for this platform. '
        'If you just added the plugin, a full restart (not a hot reload) is '
        'needed to register it.',
      );
    }
  }

  WhatsAppShareException _translate(
    PlatformException error,
    Map<String, Object?>? arguments,
  ) {
    final message = error.message ?? 'The platform reported an unknown error.';
    switch (error.code) {
      case 'APP_NOT_INSTALLED':
        final rawTarget = arguments?['target'];
        return WhatsAppNotInstalledException(
          rawTarget is String
              ? WhatsAppTarget.fromWireName(rawTarget)
              : WhatsAppTarget.standard,
        );
      case 'INVALID_ARGUMENT':
        return InvalidShareArgumentException(message);
      case 'FILE_NOT_FOUND':
      case 'FILE_ERROR':
        return ShareFileException(message, code: error.code);
      case 'UNSUPPORTED_OPERATION':
        return UnsupportedShareException(message);
      case 'STICKER_PACK_ERROR':
      case 'STICKER_PACK_INVALID':
      case 'STICKER_PACK_REJECTED':
        return StickerPackException(message, code: error.code);
      default:
        return WhatsAppSharePlatformException(
          message,
          platformCode: error.code,
          details: error.details,
        );
    }
  }
}
