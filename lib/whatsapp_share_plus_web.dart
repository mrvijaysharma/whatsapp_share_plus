/// The web implementation of `whatsapp_share_plus`.
///
/// Registered automatically by the Flutter web plugin registrant; there is no
/// reason to import this library directly.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/links/phone_number.dart';
import 'src/links/whatsapp_link.dart';
import 'src/models/diagnostics.dart';
import 'src/models/exceptions.dart';
import 'src/models/share_file.dart';
import 'src/models/share_request.dart';
import 'src/models/share_result.dart';
import 'src/models/sticker_pack.dart';
import 'src/models/whatsapp_target.dart';
import 'src/platform/whatsapp_share_platform.dart';

/// Shares to WhatsApp from a browser.
///
/// The browser cannot launch a native app directly or see what the user has
/// installed, so this implementation takes two routes:
///
/// - **Text and links** open a `wa.me` URL in a new tab. WhatsApp's own page
///   then hands off to the installed app on mobile, or to WhatsApp Web on
///   desktop.
/// - **Files** go through the Web Share API when the browser supports it, which
///   puts WhatsApp in the native share sheet on Android and iOS. Browsers
///   without it — every desktop browser today — cannot attach files at all.
class WhatsappSharePlusWeb extends WhatsappSharePlusPlatform {
  /// Registers this implementation with the Flutter web plugin registry.
  static void registerWith(Registrar registrar) {
    WhatsappSharePlusPlatform.instance = WhatsappSharePlusWeb();
  }

  /// Always `false`: a browser cannot see which apps are installed.
  ///
  /// Share anyway — the `wa.me` hand-off works whether or not WhatsApp is
  /// installed, so a `false` here is not a reason to skip [share].
  @override
  Future<bool> isInstalled(WhatsAppTarget target) async => false;

  @override
  Future<Set<WhatsAppTarget>> installedTargets() async =>
      const <WhatsAppTarget>{};

  @override
  Future<ShareResult> share(ShareRequest request) async {
    request.validate();

    if (request.hasFiles) {
      return _shareFiles(request);
    }
    return _openLink(request);
  }

  @override
  Future<ShareResult> openChat(ShareRequest request) => _openLink(request);

  @override
  Future<WhatsAppDiagnostics> diagnose() async {
    final issues = <DiagnosticIssue>[];
    if (!_supportsFileShare) {
      issues.add(const DiagnosticIssue(
        code: 'NO_WEB_SHARE_API',
        description:
            'This browser does not support sharing files through the Web Share '
            'API, so file attachments cannot be sent.',
        remedy:
            'Text sharing still works. To attach files on the web, the page '
            'must be served over HTTPS and opened in a browser that implements '
            'navigator.canShare with files — currently Chrome and Safari on '
            'mobile.',
      ));
    }
    if (web.window.location.protocol != 'https:' &&
        web.window.location.hostname != 'localhost') {
      issues.add(const DiagnosticIssue(
        code: 'INSECURE_CONTEXT',
        description: 'The Web Share API is only available in a secure context.',
        remedy: 'Serve the app over HTTPS.',
      ));
    }
    return WhatsAppDiagnostics(
      platform: 'web',
      installedTargets: const <WhatsAppTarget>{},
      issues: issues,
    );
  }

  @override
  Future<bool> isStickerPackSupported() async => false;

  @override
  Future<bool> addStickerPack(StickerPack pack, WhatsAppTarget target) async {
    throw const UnsupportedShareException(
      'WhatsApp sticker packs can only be installed from the Android and iOS '
      'apps. There is no browser equivalent.',
    );
  }

  Future<ShareResult> _openLink(ShareRequest request) async {
    final normalized = WhatsAppPhoneNumber.normalize(request.phone);
    final uri = WhatsAppLink.chat(phone: normalized, text: request.text);
    final opened = web.window.open(uri.toString(), '_blank');
    // A null-ish handle means a popup blocker intervened; navigating the
    // current tab is a worse experience but beats doing nothing silently.
    if (opened.isUndefinedOrNull) {
      web.window.location.href = uri.toString();
    }
    return ShareResult(
      status: ShareStatus.fallback,
      target: request.target,
      message: 'Opened ${uri.host} in the browser.',
    );
  }

  Future<ShareResult> _shareFiles(ShareRequest request) async {
    final inMemory = request.files.where((file) => file.isInMemory).toList();
    if (inMemory.length != request.files.length) {
      throw const UnsupportedShareException(
        'The web has no file system to read paths from. Build files with '
        'ShareFile.fromBytes instead of ShareFile.fromPath when targeting web.',
      );
    }
    if (!_supportsFileShare) {
      throw const UnsupportedShareException(
        'This browser cannot share files. Share text only, or call '
        'WhatsAppShare.diagnose() for details.',
      );
    }

    final data = web.ShareData(
      files: inMemory.map(_toJsFile).toList().toJS,
      text: request.text ?? '',
    );

    if (!web.window.navigator.canShare(data)) {
      throw const UnsupportedShareException(
        'This browser refused to share the given files. Image and PDF '
        'attachments have the widest support.',
      );
    }

    try {
      await web.window.navigator.share(data).toDart;
      return ShareResult(
        status: ShareStatus.sheetPresented,
        message: 'Handed off to the browser share sheet.',
      );
    } on Object catch (error) {
      // The Web Share API rejects with AbortError when the user closes the
      // sheet, which is a normal outcome rather than a failure.
      if (error.toString().contains('AbortError')) {
        return const ShareResult(status: ShareStatus.dismissed);
      }
      rethrow;
    }
  }

  web.File _toJsFile(ShareFile file) {
    final parts = <JSAny>[file.bytes!.toJS].toJS;
    return web.File(
      parts,
      file.name ?? 'attachment',
      web.FilePropertyBag(type: file.mimeType ?? 'application/octet-stream'),
    );
  }

  /// Whether this browser exposes the Web Share API with file support.
  bool get _supportsFileShare =>
      web.window.navigator.has('canShare') && web.window.navigator.has('share');
}
