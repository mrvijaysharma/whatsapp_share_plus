import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

/// Builds a WebP header in the extended (VP8X) form, which is the only form
/// that can declare animation.
Uint8List webp({
  required int width,
  required int height,
  bool animated = false,
  int padding = 0,
}) {
  final bytes = Uint8List(30 + padding);
  bytes.setAll(0, 'RIFF'.codeUnits);
  bytes.setAll(8, 'WEBP'.codeUnits);
  bytes.setAll(12, 'VP8X'.codeUnits);
  bytes[16] = 10; // Chunk payload length.
  bytes[20] = animated ? 0x02 : 0x00; // Feature flags.

  void writeUint24LE(int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
  }

  writeUint24LE(24, width - 1);
  writeUint24LE(27, height - 1);
  return bytes;
}

/// Builds a PNG header carrying the given dimensions.
Uint8List png({required int width, required int height, int padding = 0}) {
  final bytes = Uint8List(24 + padding);
  bytes.setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(12, 'IHDR'.codeUnits);

  void writeUint32BE(int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  writeUint32BE(16, width);
  writeUint32BE(20, height);
  return bytes;
}

Sticker validSticker() => Sticker(
      image: ShareFile.fromBytes(
        webp(width: 512, height: 512),
        name: 'sticker.webp',
      ),
      emojis: const <String>['😀'],
    );

StickerPack packWith({
  List<Sticker>? stickers,
  ShareFile? trayImage,
  bool animated = false,
  String identifier = 'demo-pack',
  String name = 'Demo Pack',
  String publisher = 'Demo Publisher',
}) {
  return StickerPack(
    identifier: identifier,
    name: name,
    publisher: publisher,
    animated: animated,
    trayImage: trayImage ??
        ShareFile.fromBytes(png(width: 96, height: 96), name: 'tray.png'),
    stickers: stickers ?? List<Sticker>.generate(3, (_) => validSticker()),
  );
}

void main() {
  group('parseImageHeader', () {
    test('reads WebP dimensions from a VP8X header', () {
      final header = parseImageHeader(webp(width: 512, height: 512))!;
      expect(header.width, 512);
      expect(header.height, 512);
      expect(header.format, 'webp');
      expect(header.isAnimated, isFalse);
    });

    test('detects an animated WebP', () {
      final header =
          parseImageHeader(webp(width: 512, height: 512, animated: true))!;
      expect(header.isAnimated, isTrue);
    });

    test('reads PNG dimensions', () {
      final header = parseImageHeader(png(width: 96, height: 96))!;
      expect(header.width, 96);
      expect(header.height, 96);
      expect(header.format, 'png');
    });

    test('reads JPEG dimensions from the start-of-frame marker', () {
      final bytes = Uint8List.fromList(<int>[
        0xFF, 0xD8, // SOI
        0xFF, 0xC0, // SOF0
        0x00, 0x11, // Segment length
        0x08, // Sample precision
        0x01, 0x40, // Height: 320
        0x00, 0xF0, // Width: 240
        0x03,
      ]);
      final header = parseImageHeader(bytes)!;
      expect(header.width, 240);
      expect(header.height, 320);
      expect(header.format, 'jpeg');
    });

    test('returns null for bytes that are not an image', () {
      expect(parseImageHeader(Uint8List.fromList(List<int>.filled(40, 7))),
          isNull);
    });

    test('returns null for a truncated header', () {
      expect(parseImageHeader(Uint8List.fromList('RIFF'.codeUnits)), isNull);
    });
  });

  group('StickerPack.validate', () {
    test('accepts a pack that meets every requirement', () async {
      expect(await packWith().validate(), isEmpty);
    });

    test('rejects a pack with too few stickers', () async {
      final problems = await packWith(
        stickers: <Sticker>[validSticker(), validSticker()],
      ).validate();
      expect(problems.single, contains('between 3 and 30 stickers'));
    });

    test('rejects a pack with too many stickers', () async {
      final problems = await packWith(
        stickers: List<Sticker>.generate(31, (_) => validSticker()),
      ).validate();
      expect(problems.first, contains('between 3 and 30 stickers'));
    });

    test('rejects a sticker with the wrong dimensions', () async {
      final problems = await packWith(
        stickers: <Sticker>[
          Sticker(
            image: ShareFile.fromBytes(
              webp(width: 256, height: 256),
              name: 'small.webp',
            ),
          ),
          validSticker(),
          validSticker(),
        ],
      ).validate();
      expect(problems.single, contains('must be 512x512 but is 256x256'));
    });

    test('rejects a sticker that is not WebP', () async {
      final problems = await packWith(
        stickers: <Sticker>[
          Sticker(
            image: ShareFile.fromBytes(
              png(width: 512, height: 512),
              name: 'sticker.png',
            ),
          ),
          validSticker(),
          validSticker(),
        ],
      ).validate();
      expect(problems.single, contains('must be a WebP image'));
    });

    test('rejects a static sticker in a pack declared animated', () async {
      final problems = await packWith(animated: true).validate();
      expect(problems, hasLength(3));
      expect(problems.first, contains('does not allow mixing'));
    });

    test('rejects a sticker over the size limit', () async {
      final problems = await packWith(
        stickers: <Sticker>[
          Sticker(
            image: ShareFile.fromBytes(
              webp(width: 512, height: 512, padding: 101 * 1024),
              name: 'huge.webp',
            ),
          ),
          validSticker(),
          validSticker(),
        ],
      ).validate();
      expect(
          problems.single, contains('the limit for static stickers is 100 KB'));
    });

    test('rejects a tray image with the wrong dimensions', () async {
      final problems = await packWith(
        trayImage: ShareFile.fromBytes(
          png(width: 512, height: 512),
          name: 'tray.png',
        ),
      ).validate();
      expect(problems.single, contains('trayImage must be 96x96'));
    });

    test('rejects an oversized tray image', () async {
      final problems = await packWith(
        trayImage: ShareFile.fromBytes(
          png(width: 96, height: 96, padding: 51 * 1024),
          name: 'tray.png',
        ),
      ).validate();
      expect(problems.single, contains('the limit is 50 KB'));
    });

    test('rejects too many emojis on one sticker', () async {
      final problems = await packWith(
        stickers: <Sticker>[
          Sticker(
            image: ShareFile.fromBytes(
              webp(width: 512, height: 512),
              name: 'sticker.webp',
            ),
            emojis: const <String>['😀', '😃', '😄', '😁'],
          ),
          validSticker(),
          validSticker(),
        ],
      ).validate();
      expect(problems.single, contains('the limit is 3'));
    });

    test('rejects identifiers that could escape a directory', () async {
      final problems = await packWith(identifier: '../escape').validate();
      expect(problems.single, contains('must not contain'));
    });

    test('rejects empty required strings', () async {
      final problems = await packWith(name: '', publisher: '  ').validate();
      expect(problems, hasLength(2));
    });

    test('validateOrThrow reports every problem at once', () async {
      await expectLater(
        packWith(identifier: '', stickers: <Sticker>[]).validateOrThrow(),
        throwsA(
          isA<StickerPackException>().having(
            (error) => error.message,
            'message',
            allOf(contains('identifier'), contains('stickers')),
          ),
        ),
      );
    });

    test('validateOrThrow stays quiet for a valid pack', () async {
      await expectLater(packWith().validateOrThrow(), completes);
    });
  });
}
