import 'dart:ui' show Rect;

import 'exceptions.dart';
import 'share_file.dart';
import 'whatsapp_target.dart';

/// Everything needed to perform one share, bundled into a single value.
///
/// Platform implementations receive this rather than a long parameter list, so
/// adding a capability does not change every signature in the package.
class ShareRequest {
  /// Creates a share request.
  ///
  /// At least one of [text] or [files] must carry content; a request with
  /// neither is rejected by [validate].
  const ShareRequest({
    this.text,
    this.files = const <ShareFile>[],
    this.phone,
    this.target = WhatsAppTarget.standard,
    this.sharePositionOrigin,
    this.allowFallback = true,
  });

  /// The message body, or the caption when [files] contains a single image or
  /// video.
  final String? text;

  /// Attachments to send. May be empty for a text-only share.
  final List<ShareFile> files;

  /// The recipient's phone number in international format.
  ///
  /// Normalised before use, so the formats users type — `+91 98765 43210` —
  /// are accepted. When `null`, WhatsApp opens its own contact picker.
  final String? phone;

  /// Which WhatsApp app to route to.
  final WhatsAppTarget target;

  /// The rectangle the share sheet should point at, in global coordinates.
  ///
  /// Required on iPad and macOS, where a share sheet is a popover that must be
  /// anchored to the control that opened it. Ignored on Android and iPhone.
  final Rect? sharePositionOrigin;

  /// Whether to fall back to a `wa.me` link when the target app cannot be
  /// opened directly.
  ///
  /// Set to `false` to receive a [WhatsAppNotInstalledException] instead of a
  /// browser hand-off.
  final bool allowFallback;

  /// Whether this request carries any attachments.
  bool get hasFiles => files.isNotEmpty;

  /// Whether this request carries message text.
  bool get hasText => text != null && text!.trim().isNotEmpty;

  /// Throws [InvalidShareArgumentException] when this request cannot produce a
  /// meaningful share.
  void validate() {
    if (!hasText && !hasFiles) {
      throw const InvalidShareArgumentException(
        'A share needs text, at least one file, or both.',
      );
    }
  }

  /// Serialises this request for transport across the platform channel.
  Map<String, Object?> toMap({String? normalizedPhone}) => <String, Object?>{
        if (text != null) 'text': text,
        'files': files.map((file) => file.toMap()).toList(),
        if (normalizedPhone != null) 'phone': normalizedPhone,
        'target': target.wireName,
        'allowFallback': allowFallback,
        if (sharePositionOrigin != null)
          'sharePositionOrigin': <String, double>{
            'left': sharePositionOrigin!.left,
            'top': sharePositionOrigin!.top,
            'width': sharePositionOrigin!.width,
            'height': sharePositionOrigin!.height,
          },
      };

  @override
  String toString() => 'ShareRequest(target: ${target.wireName}, '
      'text: ${hasText ? '${text!.length} chars' : 'none'}, '
      'files: ${files.length}, phone: ${phone == null ? 'none' : 'set'})';
}
