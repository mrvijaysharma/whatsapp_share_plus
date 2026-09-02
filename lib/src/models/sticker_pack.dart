import 'dart:typed_data';

import '../platform/file_reader.dart';
import 'exceptions.dart';
import 'image_header.dart';
import 'share_file.dart';

/// WhatsApp's structural requirements for third-party sticker packs.
///
/// These mirror the constraints WhatsApp's own sample apps enforce. A pack that
/// violates any of them is rejected at install time, usually without a useful
/// message, which is why this package checks them up front.
abstract final class StickerPackLimits {
  /// Fewest stickers a pack may contain.
  static const int minStickers = 3;

  /// Most stickers a pack may contain.
  static const int maxStickers = 30;

  /// Required width and height, in pixels, of every sticker image.
  static const int stickerDimension = 512;

  /// Required width and height, in pixels, of the tray icon.
  static const int trayDimension = 96;

  /// Maximum encoded size of a static sticker, in bytes.
  static const int maxStaticStickerBytes = 100 * 1024;

  /// Maximum encoded size of an animated sticker, in bytes.
  static const int maxAnimatedStickerBytes = 500 * 1024;

  /// Maximum encoded size of the tray icon, in bytes.
  static const int maxTrayBytes = 50 * 1024;

  /// Maximum number of emoji that may be associated with one sticker.
  static const int maxEmojisPerSticker = 3;

  /// Maximum length of the pack identifier, name, and publisher strings.
  static const int maxStringLength = 128;
}

/// One sticker within a [StickerPack].
class Sticker {
  /// Creates a sticker.
  ///
  /// [image] must be a 512x512 WebP. [emojis] associates the sticker with up to
  /// [StickerPackLimits.maxEmojisPerSticker] emoji for WhatsApp's search.
  const Sticker({
    required this.image,
    this.emojis = const <String>[],
    this.accessibilityText,
  });

  /// The sticker image: a 512x512 WebP, static or animated.
  final ShareFile image;

  /// Emoji this sticker is associated with, used by WhatsApp's sticker search.
  final List<String> emojis;

  /// A description of the sticker for screen readers.
  final String? accessibilityText;

  /// Serialises this sticker for transport across the platform channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'image': image.toMap(),
        'emojis': emojis,
        if (accessibilityText != null) 'accessibilityText': accessibilityText,
      };
}

/// A third-party sticker pack that can be installed into WhatsApp.
///
/// Installation is a handshake, not a file copy: this package publishes the
/// pack to WhatsApp and WhatsApp asks the user to confirm. The user can decline.
///
/// Call [validate] before installing to catch constraint violations while you
/// still have a useful error to show.
class StickerPack {
  /// Creates a sticker pack.
  const StickerPack({
    required this.identifier,
    required this.name,
    required this.publisher,
    required this.trayImage,
    required this.stickers,
    this.animated = false,
    this.publisherEmail,
    this.publisherWebsite,
    this.privacyPolicyWebsite,
    this.licenseAgreementWebsite,
  });

  /// A stable, unique id for this pack within your app.
  ///
  /// Reusing an identifier updates the existing pack rather than adding a
  /// second copy. Must not contain `..`, `/`, or `\`.
  final String identifier;

  /// The pack name shown to the user.
  final String name;

  /// The publisher name shown to the user.
  final String publisher;

  /// The pack's tray icon: a 96x96 PNG or WebP of at most 50 KB.
  final ShareFile trayImage;

  /// The stickers in the pack — between 3 and 30 of them.
  final List<Sticker> stickers;

  /// Whether this is an animated pack.
  ///
  /// WhatsApp does not allow mixing: either every sticker is animated or none
  /// is. [validate] enforces that against the actual image data.
  final bool animated;

  /// Contact email for the publisher.
  final String? publisherEmail;

  /// Publisher's website.
  final String? publisherWebsite;

  /// URL of the publisher's privacy policy.
  final String? privacyPolicyWebsite;

  /// URL of the publisher's license agreement.
  final String? licenseAgreementWebsite;

  /// Checks this pack against WhatsApp's requirements.
  ///
  /// Reads every image to verify format, dimensions, and encoded size, so it
  /// performs file I/O. Returns an empty list when the pack is valid.
  Future<List<String>> validate() async {
    final problems = <String>[];

    if (identifier.trim().isEmpty) {
      problems.add('identifier must not be empty.');
    } else if (identifier.length > StickerPackLimits.maxStringLength) {
      problems.add(
        'identifier must be at most ${StickerPackLimits.maxStringLength} characters.',
      );
    } else if (identifier.contains('..') ||
        identifier.contains('/') ||
        identifier.contains(r'\')) {
      problems.add(r'identifier must not contain "..", "/", or "\".');
    }

    if (name.trim().isEmpty) {
      problems.add('name must not be empty.');
    } else if (name.length > StickerPackLimits.maxStringLength) {
      problems.add(
        'name must be at most ${StickerPackLimits.maxStringLength} characters.',
      );
    }

    if (publisher.trim().isEmpty) {
      problems.add('publisher must not be empty.');
    } else if (publisher.length > StickerPackLimits.maxStringLength) {
      problems.add(
        'publisher must be at most ${StickerPackLimits.maxStringLength} characters.',
      );
    }

    if (stickers.length < StickerPackLimits.minStickers ||
        stickers.length > StickerPackLimits.maxStickers) {
      problems.add(
        'A pack must contain between ${StickerPackLimits.minStickers} and '
        '${StickerPackLimits.maxStickers} stickers, but has ${stickers.length}.',
      );
    }

    final trayBytes = await _bytesOf(trayImage);
    if (trayBytes == null) {
      problems.add('trayImage could not be read.');
    } else {
      if (trayBytes.length > StickerPackLimits.maxTrayBytes) {
        problems.add(
          'trayImage is ${_kb(trayBytes.length)} KB; the limit is '
          '${StickerPackLimits.maxTrayBytes ~/ 1024} KB.',
        );
      }
      final header = parseImageHeader(trayBytes);
      if (header == null) {
        problems.add('trayImage is not a readable PNG or WebP.');
      } else if (header.width != StickerPackLimits.trayDimension ||
          header.height != StickerPackLimits.trayDimension) {
        problems.add(
          'trayImage must be ${StickerPackLimits.trayDimension}x'
          '${StickerPackLimits.trayDimension} but is ${header.width}x${header.height}.',
        );
      }
    }

    for (var i = 0; i < stickers.length; i++) {
      final sticker = stickers[i];
      final label = 'stickers[$i]';

      if (sticker.emojis.length > StickerPackLimits.maxEmojisPerSticker) {
        problems.add(
          '$label has ${sticker.emojis.length} emojis; the limit is '
          '${StickerPackLimits.maxEmojisPerSticker}.',
        );
      }

      final bytes = await _bytesOf(sticker.image);
      if (bytes == null) {
        problems.add('$label could not be read.');
        continue;
      }

      final header = parseImageHeader(bytes);
      if (header == null || header.format != 'webp') {
        problems.add('$label must be a WebP image.');
        continue;
      }

      if (header.width != StickerPackLimits.stickerDimension ||
          header.height != StickerPackLimits.stickerDimension) {
        problems.add(
          '$label must be ${StickerPackLimits.stickerDimension}x'
          '${StickerPackLimits.stickerDimension} but is ${header.width}x${header.height}.',
        );
      }

      if (header.isAnimated != animated) {
        problems.add(
          '$label is ${header.isAnimated ? 'animated' : 'static'} but the pack '
          'is declared ${animated ? 'animated' : 'static'}. WhatsApp does not '
          'allow mixing animated and static stickers in one pack.',
        );
      }

      final limit = animated
          ? StickerPackLimits.maxAnimatedStickerBytes
          : StickerPackLimits.maxStaticStickerBytes;
      if (bytes.length > limit) {
        problems.add(
          '$label is ${_kb(bytes.length)} KB; the limit for '
          '${animated ? 'animated' : 'static'} stickers is ${limit ~/ 1024} KB.',
        );
      }
    }

    return problems;
  }

  /// Runs [validate] and throws a [StickerPackException] if anything is wrong.
  Future<void> validateOrThrow() async {
    final problems = await validate();
    if (problems.isNotEmpty) {
      throw StickerPackException(
        'Sticker pack "$name" is not valid:\n  - ${problems.join('\n  - ')}',
        code: 'STICKER_PACK_INVALID',
      );
    }
  }

  /// Serialises this pack for transport across the platform channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'identifier': identifier,
        'name': name,
        'publisher': publisher,
        'trayImage': trayImage.toMap(),
        'stickers': stickers.map((sticker) => sticker.toMap()).toList(),
        'animated': animated,
        if (publisherEmail != null) 'publisherEmail': publisherEmail,
        if (publisherWebsite != null) 'publisherWebsite': publisherWebsite,
        if (privacyPolicyWebsite != null)
          'privacyPolicyWebsite': privacyPolicyWebsite,
        if (licenseAgreementWebsite != null)
          'licenseAgreementWebsite': licenseAgreementWebsite,
      };

  static Future<Uint8List?> _bytesOf(ShareFile file) async {
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null || !canReadFiles) return null;
    try {
      return await readFileBytes(path);
    } on Object {
      return null;
    }
  }

  static String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);
}
