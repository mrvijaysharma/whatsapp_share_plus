import '../models/share_file.dart';
import '../models/share_result.dart';
import '../models/whatsapp_target.dart';
import '../whatsapp_share.dart';

/// The 1.x API, preserved so existing code keeps compiling.
///
/// Every method here forwards to [WhatsAppShare]. The replacements return a
/// [ShareResult] instead of `bool?` and raise typed exceptions, which is what
/// makes real error handling possible. See `MIGRATION.md` for a side-by-side
/// mapping.
///
/// Scheduled for removal in 3.0.0.
@Deprecated(
  'Use WhatsAppShare instead. WhatsappSharePlus will be removed in 3.0.0. '
  'See MIGRATION.md.',
)
abstract final class WhatsappSharePlus {
  /// Superseded by `WhatsAppShare.isInstalled()`.
  @Deprecated(
    'Use WhatsAppShare.isInstalled(). Will be removed in 3.0.0.',
  )
  static Future<bool> isWhatsappInstalled() => WhatsAppShare.isInstalled();

  /// Superseded by `WhatsAppShare.isInstalled(target: WhatsAppTarget.business)`.
  @Deprecated(
    'Use WhatsAppShare.isInstalled(target: WhatsAppTarget.business). '
    'Will be removed in 3.0.0.',
  )
  static Future<bool> isWhatsappBusinessInstalled() =>
      WhatsAppShare.isInstalled(target: WhatsAppTarget.business);

  /// Superseded by `WhatsAppShare.share(text: ...)`.
  @Deprecated(
    'Use WhatsAppShare.share(text: ...). Will be removed in 3.0.0.',
  )
  static Future<bool?> shareToWhatsapp({
    required String text,
    String? phone,
  }) async {
    final result = await WhatsAppShare.share(text: text, phone: phone);
    return result.isSuccess;
  }

  /// Superseded by
  /// `WhatsAppShare.share(text: ..., target: WhatsAppTarget.business)`.
  @Deprecated(
    'Use WhatsAppShare.share(text: ..., target: WhatsAppTarget.business). '
    'Will be removed in 3.0.0.',
  )
  static Future<bool?> shareToWhatsappBusiness({
    required String text,
    String? phone,
  }) async {
    final result = await WhatsAppShare.share(
      text: text,
      phone: phone,
      target: WhatsAppTarget.business,
    );
    return result.isSuccess;
  }

  /// Superseded by `WhatsAppShare.share(files: [ShareFile.fromPath(...)])`.
  @Deprecated(
    'Use WhatsAppShare.share(files: [ShareFile.fromPath(...)]). '
    'Will be removed in 3.0.0.',
  )
  static Future<bool?> shareImageToWhatsapp({
    required String imagePath,
    String? text,
    String? phone,
  }) async {
    final result = await WhatsAppShare.share(
      text: text,
      phone: phone,
      files: <ShareFile>[ShareFile.fromPath(imagePath)],
    );
    return result.isSuccess;
  }

  /// Superseded by `WhatsAppShare.share(files: ..., target:
  /// WhatsAppTarget.business)`.
  @Deprecated(
    'Use WhatsAppShare.share(files: [...], target: WhatsAppTarget.business). '
    'Will be removed in 3.0.0.',
  )
  static Future<bool?> shareImageToWhatsappBusiness({
    required String imagePath,
    String? text,
    String? phone,
  }) async {
    final result = await WhatsAppShare.share(
      text: text,
      phone: phone,
      target: WhatsAppTarget.business,
      files: <ShareFile>[ShareFile.fromPath(imagePath)],
    );
    return result.isSuccess;
  }
}
