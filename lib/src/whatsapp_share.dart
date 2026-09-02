import 'dart:ui' show Rect;

import 'links/phone_number.dart';
import 'models/diagnostics.dart';
import 'models/exceptions.dart';
import 'models/share_file.dart';
import 'models/share_request.dart';
import 'models/share_result.dart';
import 'models/sticker_pack.dart';
import 'models/whatsapp_target.dart';
import 'platform/whatsapp_share_platform.dart';

/// Shares text, media, and documents to WhatsApp and WhatsApp Business.
///
/// The whole surface is one [share] call plus a few focused helpers:
///
/// ```dart
/// await WhatsAppShare.share(
///   text: 'Here is the invoice.',
///   files: [ShareFile.fromPath('/tmp/invoice.pdf')],
///   phone: '+91 98765 43210',
/// );
/// ```
///
/// Every method throws a [WhatsAppShareException] subtype on failure rather
/// than returning a bare `false`, so callers can tell "WhatsApp is missing"
/// apart from "that file could not be read".
///
/// ## Platform differences that matter
///
/// WhatsApp exposes different capabilities on each platform, and no wrapper can
/// paper over that. The important cases:
///
/// - **Sending to a specific contact with an attachment** works on Android
///   only. On other platforms the attachment goes to a picker where the user
///   chooses the recipient.
/// - **Multiple files at once** works on Android and iOS. On iOS it always
///   opens the system share sheet.
/// - **Targeting WhatsApp Business specifically** is reliable on Android. On
///   iOS it depends on a URL scheme that WhatsApp does not formally document.
/// - **Web and desktop** have no native share; they open a `wa.me` link, which
///   carries text but never files.
///
/// Call [diagnose] during development to check the host app's configuration.
abstract final class WhatsAppShare {
  static WhatsappSharePlusPlatform get _platform =>
      WhatsappSharePlusPlatform.instance;

  /// Whether [target] is installed on this device.
  ///
  /// On Android this requires the `<queries>` entries the plugin's manifest
  /// contributes; on iOS it requires `LSApplicationQueriesSchemes` in the host
  /// app's `Info.plist`. When either is missing this reports `false` for an app
  /// that is actually present — [diagnose] detects exactly that case.
  ///
  /// Always `false` on the web, where installed apps cannot be detected.
  static Future<bool> isInstalled({
    WhatsAppTarget target = WhatsAppTarget.standard,
  }) {
    return _platform.isInstalled(target);
  }

  /// Every WhatsApp app installed on this device.
  ///
  /// Useful for deciding whether to show a target picker: an empty set means
  /// neither app is present, and a set of one means there is nothing to choose.
  static Future<Set<WhatsAppTarget>> installedTargets() {
    return _platform.installedTargets();
  }

  /// Sends [text], [files], or both to WhatsApp.
  ///
  /// At least one of [text] and [files] must carry content.
  ///
  /// When [files] holds exactly one image or video, [text] becomes its caption.
  /// With multiple files, or a document, WhatsApp ignores the caption on most
  /// platforms and sends the text as a separate message or not at all.
  ///
  /// [phone] addresses a specific contact and accepts any common format —
  /// `+91 98765 43210`, `0091 98765-43210`, `919876543210` all work. Omit it to
  /// let the user pick a recipient. Note the platform limits above: with
  /// attachments, contact targeting is Android-only.
  ///
  /// [sharePositionOrigin] anchors the share sheet popover and is required on
  /// iPad and macOS; pass the bounds of the button that triggered the share.
  ///
  /// When [allowFallback] is `true` (the default) and the target app cannot be
  /// opened, a text-only share is retried as a `wa.me` link and the result
  /// reports [ShareStatus.fallback]. Files are never sent this way — a link
  /// cannot carry them — so a share with attachments still throws
  /// [WhatsAppNotInstalledException].
  ///
  /// Throws [InvalidShareArgumentException] for an empty payload or an
  /// unparseable [phone], [ShareFileException] when a file cannot be read, and
  /// [WhatsAppNotInstalledException] when the app is missing and no fallback
  /// applies.
  static Future<ShareResult> share({
    String? text,
    List<ShareFile> files = const <ShareFile>[],
    String? phone,
    WhatsAppTarget target = WhatsAppTarget.standard,
    Rect? sharePositionOrigin,
    bool allowFallback = true,
  }) {
    final request = ShareRequest(
      text: text,
      files: files,
      phone: phone,
      target: target,
      sharePositionOrigin: sharePositionOrigin,
      allowFallback: allowFallback,
    );
    request.validate();
    if (phone != null) {
      // Fail here rather than deep in a platform channel, so the stack trace
      // points at the caller's bad input.
      WhatsAppPhoneNumber.parse(phone);
    }
    return _platform.share(request);
  }

  /// Opens a conversation with [phone], optionally pre-filling [text].
  ///
  /// Unlike [share] this never attaches files, which means it works on every
  /// platform including the web — where it opens WhatsApp Web.
  ///
  /// Throws [InvalidShareArgumentException] when [phone] is not a valid
  /// international number.
  static Future<ShareResult> openChat({
    required String phone,
    String? text,
    WhatsAppTarget target = WhatsAppTarget.standard,
    bool allowFallback = true,
  }) {
    WhatsAppPhoneNumber.parse(phone);
    return _platform.openChat(
      ShareRequest(
        text: text,
        phone: phone,
        target: target,
        allowFallback: allowFallback,
      ),
    );
  }

  /// Reports configuration problems in the host app that would break sharing.
  ///
  /// Most "WhatsApp is not installed" reports from users are really a missing
  /// `LSApplicationQueriesSchemes` entry or a stripped Android `<queries>` tag.
  /// Print this in a debug build to see the actual cause:
  ///
  /// ```dart
  /// if (kDebugMode) debugPrint((await WhatsAppShare.diagnose()).toString());
  /// ```
  static Future<WhatsAppDiagnostics> diagnose() => _platform.diagnose();

  /// Whether this platform can install sticker packs.
  ///
  /// `true` on Android and iOS, `false` everywhere else.
  static Future<bool> isStickerPackSupported() =>
      _platform.isStickerPackSupported();

  /// Offers [pack] to WhatsApp for installation.
  ///
  /// WhatsApp asks the user to confirm; returns `true` if they accepted and
  /// `false` if they declined. The pack is validated against WhatsApp's
  /// requirements first — see [StickerPack.validate] — because WhatsApp itself
  /// rejects malformed packs without explaining why.
  ///
  /// On iOS the user's decision is not reported back — a `true` there means
  /// WhatsApp received the pack, not that the user kept it.
  ///
  /// Throws [StickerPackException] when the pack is invalid or WhatsApp refuses
  /// it, and [UnsupportedShareException] on platforms without sticker support.
  static Future<bool> addStickerPack(
    StickerPack pack, {
    WhatsAppTarget target = WhatsAppTarget.standard,
  }) =>
      _platform.addStickerPack(pack, target);
}
