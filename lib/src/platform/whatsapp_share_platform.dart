import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/diagnostics.dart';
import '../models/share_file.dart';
import '../models/share_request.dart';
import '../models/share_result.dart';
import '../models/sticker_pack.dart';
import '../models/whatsapp_target.dart';
import 'method_channel_whatsapp_share.dart';

/// The interface every platform implementation of this plugin satisfies.
///
/// Implementations must extend this class rather than implement it, so that
/// new capabilities can be added without breaking every subclass. Test doubles
/// are the exception: they may use `implements` together with
/// `MockPlatformInterfaceMixin`.
abstract class WhatsappSharePlusPlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  WhatsappSharePlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static WhatsappSharePlusPlatform _instance = MethodChannelWhatsappSharePlus();

  /// The active platform implementation.
  ///
  /// Defaults to [MethodChannelWhatsappSharePlus] on platforms with native
  /// code, and is replaced by the registrant on the web.
  static WhatsappSharePlusPlatform get instance => _instance;

  /// Sets the active platform implementation.
  static set instance(WhatsappSharePlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Whether [target] is installed on this device.
  Future<bool> isInstalled(WhatsAppTarget target);

  /// Every WhatsApp app installed on this device.
  Future<Set<WhatsAppTarget>> installedTargets();

  /// Performs [request], returning how it resolved.
  Future<ShareResult> share(ShareRequest request);

  /// Opens a conversation without sending an attachment.
  Future<ShareResult> openChat(ShareRequest request);

  /// Reports host-app configuration problems that would break sharing.
  Future<WhatsAppDiagnostics> diagnose();

  /// Publishes [pack] to [target] for the user to confirm.
  ///
  /// Returns `true` when WhatsApp reported the pack as added, `false` when the
  /// user declined.
  Future<bool> addStickerPack(StickerPack pack, WhatsAppTarget target);

  /// Whether sticker pack installation is available on this platform.
  Future<bool> isStickerPackSupported() async => false;

  // ---------------------------------------------------------------------------
  // Legacy surface.
  //
  // Implemented here in terms of the methods above so that platform
  // implementations do not have to carry them, and so existing callers keep
  // working unchanged. Superseded by [share]; see MIGRATION.md.
  // ---------------------------------------------------------------------------

  /// Superseded by [isInstalled].
  Future<bool> isWhatsappInstalled() => isInstalled(WhatsAppTarget.standard);

  /// Superseded by [isInstalled].
  Future<bool> isWhatsappBusinessInstalled() =>
      isInstalled(WhatsAppTarget.business);

  /// Superseded by [share].
  Future<bool?> shareToWhatsapp({required String text, String? phone}) async {
    final result = await share(
      ShareRequest(text: text, phone: phone),
    );
    return result.isSuccess;
  }

  /// Superseded by [share].
  Future<bool?> shareToWhatsappBusiness({
    required String text,
    String? phone,
  }) async {
    final result = await share(
      ShareRequest(text: text, phone: phone, target: WhatsAppTarget.business),
    );
    return result.isSuccess;
  }

  /// Superseded by [share].
  Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) async {
    final result = await share(
      ShareRequest(
        text: text,
        phone: phone,
        files: <ShareFile>[ShareFile.fromPath(imagePath)],
      ),
    );
    return result.isSuccess;
  }

  /// Superseded by [share].
  Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) async {
    final result = await share(
      ShareRequest(
        text: text,
        phone: phone,
        target: WhatsAppTarget.business,
        files: <ShareFile>[ShareFile.fromPath(imagePath)],
      ),
    );
    return result.isSuccess;
  }
}
