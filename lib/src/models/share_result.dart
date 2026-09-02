import 'whatsapp_target.dart';

/// How a share attempt actually resolved.
///
/// The values distinguish outcomes that a plain `bool` cannot: handing the
/// payload to WhatsApp, showing a picker, and falling back to a browser are
/// all "not a failure", but callers often want to treat them differently.
enum ShareStatus {
  /// WhatsApp was launched directly with the payload.
  ///
  /// This does not promise the user pressed send — no WhatsApp API reports
  /// that. It means the app opened with the content loaded.
  opened,

  /// The system share sheet was presented and the user chose a destination.
  ///
  /// Used on iOS for multi-file shares and for WhatsApp Business, where the
  /// platform does not allow targeting one app programmatically.
  sheetPresented,

  /// The share was completed through a `wa.me` or `web.whatsapp.com` link
  /// rather than the installed app.
  fallback,

  /// The user dismissed the share sheet without picking a destination.
  ///
  /// Only reported on iOS and the web, the two platforms whose share APIs
  /// report the user's decision. Android intents are fire-and-forget, and the
  /// macOS sharing picker offers no completion callback, so neither can tell a
  /// dismissal from a completed share.
  dismissed,
}

/// The outcome of a share attempt.
class ShareResult {
  /// Creates a result. Prefer reading results returned by the package rather
  /// than constructing them, except in tests and fake platform implementations.
  const ShareResult({
    required this.status,
    this.target,
    this.message,
  });

  /// Builds a [ShareResult] from a platform channel payload.
  factory ShareResult.fromMap(Map<Object?, Object?> map) {
    final rawStatus = map['status'] as String?;
    return ShareResult(
      status: ShareStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => ShareStatus.opened,
      ),
      target: map['target'] is String
          ? WhatsAppTarget.fromWireName(map['target']! as String)
          : null,
      message: map['message'] as String?,
    );
  }

  /// How the share resolved.
  final ShareStatus status;

  /// The app the payload was routed to, when the platform could determine it.
  ///
  /// This is `null` after a [ShareStatus.sheetPresented] result, because the
  /// system share sheet does not report which app the user picked.
  final WhatsAppTarget? target;

  /// Optional detail about the outcome, useful for logging.
  final String? message;

  /// Whether the payload reached WhatsApp by some route.
  ///
  /// `false` only when the user dismissed a share sheet.
  bool get isSuccess => status != ShareStatus.dismissed;

  /// Whether the payload was delivered through a link rather than the app.
  bool get usedFallback => status == ShareStatus.fallback;

  @override
  String toString() => 'ShareResult(${status.name}'
      '${target == null ? '' : ', target: ${target!.displayName}'}'
      '${message == null ? '' : ', message: $message'})';
}
