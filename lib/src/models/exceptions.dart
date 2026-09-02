import 'whatsapp_target.dart';

/// Base class for every error this package raises deliberately.
///
/// Catch this to handle all package failures uniformly, or switch over the
/// sealed subtypes to react to a specific cause.
sealed class WhatsAppShareException implements Exception {
  const WhatsAppShareException(this.message, {this.code});

  /// A human-readable description of what went wrong.
  final String message;

  /// A stable, machine-readable identifier for the failure.
  final String? code;

  @override
  String toString() => 'WhatsAppShareException(${code ?? 'unknown'}): $message';
}

/// Thrown when the requested WhatsApp app is not installed on the device.
final class WhatsAppNotInstalledException extends WhatsAppShareException {
  /// Creates an exception naming the [target] that could not be found.
  const WhatsAppNotInstalledException(this.target)
      : super(
          '${target == WhatsAppTarget.business ? 'WhatsApp Business' : 'WhatsApp'} '
          'is not installed on this device.',
          code: 'APP_NOT_INSTALLED',
        );

  /// The app that was requested but could not be found.
  final WhatsAppTarget target;

  @override
  String toString() => 'WhatsAppNotInstalledException: $message';
}

/// Thrown when the arguments passed to a share call cannot produce a valid
/// share — for example an empty payload, or a malformed phone number.
final class InvalidShareArgumentException extends WhatsAppShareException {
  /// Creates an exception describing why an argument was unusable.
  const InvalidShareArgumentException(super.message, {this.argument})
      : super(code: 'INVALID_ARGUMENT');

  /// The name of the offending parameter, when a single one is at fault.
  final String? argument;

  @override
  String toString() =>
      'InvalidShareArgumentException${argument == null ? '' : ' ($argument)'}: $message';
}

/// Thrown when a file selected for sharing cannot be read, staged, or sent.
final class ShareFileException extends WhatsAppShareException {
  /// Creates an exception describing a file that could not be shared.
  const ShareFileException(super.message,
      {this.path, super.code = 'FILE_ERROR'});

  /// The path of the file that could not be shared, when known.
  final String? path;

  @override
  String toString() =>
      'ShareFileException${path == null ? '' : ' ($path)'}: $message';
}

/// Thrown when an operation is not available on the current platform, or not
/// supported by WhatsApp itself on that platform.
final class UnsupportedShareException extends WhatsAppShareException {
  /// Creates an exception explaining what this platform cannot do.
  const UnsupportedShareException(super.message)
      : super(code: 'UNSUPPORTED_OPERATION');

  @override
  String toString() => 'UnsupportedShareException: $message';
}

/// Thrown when a sticker pack fails WhatsApp's structural requirements, or
/// when WhatsApp rejects the pack at install time.
final class StickerPackException extends WhatsAppShareException {
  /// Creates an exception describing why a sticker pack was refused.
  const StickerPackException(super.message,
      {super.code = 'STICKER_PACK_ERROR'});

  @override
  String toString() => 'StickerPackException: $message';
}

/// Thrown when the platform reports a failure this package does not recognise.
///
/// [platformCode] and [details] carry the raw values from the underlying
/// `PlatformException` so they are not lost in translation.
final class WhatsAppSharePlatformException extends WhatsAppShareException {
  /// Wraps an unrecognised native failure, preserving its original code.
  const WhatsAppSharePlatformException(
    super.message, {
    this.platformCode,
    this.details,
  }) : super(code: 'PLATFORM_ERROR');

  /// The original error code reported by the native side.
  final String? platformCode;

  /// Any extra payload the native side attached to the error.
  final Object? details;

  @override
  String toString() =>
      'WhatsAppSharePlatformException(${platformCode ?? 'unknown'}): $message';
}
