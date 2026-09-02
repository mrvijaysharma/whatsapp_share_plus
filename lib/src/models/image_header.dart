import 'dart:typed_data';

/// The pixel dimensions and container format of an encoded image, read from
/// its header without decoding the pixels.
class ImageHeader {
  /// Creates a header description.
  const ImageHeader({
    required this.width,
    required this.height,
    required this.format,
    this.isAnimated = false,
  });

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Container format, one of `webp`, `png`, or `jpeg`.
  final String format;

  /// Whether the container declares animation frames.
  ///
  /// Only meaningful for WebP, the single animated format WhatsApp accepts.
  final bool isAnimated;

  @override
  String toString() =>
      '${width}x$height $format${isAnimated ? ' (animated)' : ''}';
}

/// Reads image dimensions from the first bytes of an encoded image.
///
/// Returns `null` when the bytes are not a PNG, JPEG, or WebP, or when the
/// header is truncated. Used to validate stickers before WhatsApp silently
/// rejects them for being the wrong size.
ImageHeader? parseImageHeader(Uint8List bytes) {
  return _parseWebP(bytes) ?? _parsePng(bytes) ?? _parseJpeg(bytes);
}

ImageHeader? _parseWebP(Uint8List bytes) {
  // RIFF container: "RIFF" <4-byte size> "WEBP" <chunk tag> ...
  if (bytes.length < 30) return null;
  if (!_matchesAscii(bytes, 0, 'RIFF') || !_matchesAscii(bytes, 8, 'WEBP')) {
    return null;
  }

  if (_matchesAscii(bytes, 12, 'VP8X')) {
    // Extended format: a flags byte, three reserved bytes, then canvas size
    // stored as two 24-bit little-endian values, each minus one.
    final flags = bytes[20];
    final width = _readUint24LE(bytes, 24) + 1;
    final height = _readUint24LE(bytes, 27) + 1;
    return ImageHeader(
      width: width,
      height: height,
      format: 'webp',
      isAnimated: (flags & 0x02) != 0,
    );
  }

  if (_matchesAscii(bytes, 12, 'VP8 ')) {
    // Lossy: a 3-byte frame tag, then the 3-byte sync code 9d 01 2a, then
    // 14-bit width and height.
    if (bytes.length < 30) return null;
    final hasSyncCode =
        bytes[23] == 0x9D && bytes[24] == 0x01 && bytes[25] == 0x2A;
    if (!hasSyncCode) return null;
    final width = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
    final height = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
    return ImageHeader(width: width, height: height, format: 'webp');
  }

  if (_matchesAscii(bytes, 12, 'VP8L')) {
    // Lossless: signature byte 0x2f, then 14-bit width-1 and 14-bit height-1
    // packed little-endian across the following four bytes.
    if (bytes.length < 25 || bytes[20] != 0x2F) return null;
    final bits =
        bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
    final width = (bits & 0x3FFF) + 1;
    final height = ((bits >> 14) & 0x3FFF) + 1;
    return ImageHeader(width: width, height: height, format: 'webp');
  }

  return null;
}

ImageHeader? _parsePng(Uint8List bytes) {
  // 8-byte signature, then an IHDR chunk whose first two fields are the
  // big-endian width and height.
  const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  return ImageHeader(
    width: _readUint32BE(bytes, 16),
    height: _readUint32BE(bytes, 20),
    format: 'png',
  );
}

ImageHeader? _parseJpeg(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  // Walk the marker segments until a Start Of Frame carries the dimensions.
  var offset = 2;
  while (offset + 9 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    // SOF0..SOF15, excluding the non-frame markers DHT, JPG, and DAC.
    final isStartOfFrame = marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isStartOfFrame) {
      return ImageHeader(
        width: _readUint16BE(bytes, offset + 7),
        height: _readUint16BE(bytes, offset + 5),
        format: 'jpeg',
      );
    }
    final segmentLength = _readUint16BE(bytes, offset + 2);
    if (segmentLength < 2) return null;
    offset += 2 + segmentLength;
  }
  return null;
}

bool _matchesAscii(Uint8List bytes, int offset, String value) {
  if (offset + value.length > bytes.length) return false;
  for (var i = 0; i < value.length; i++) {
    if (bytes[offset + i] != value.codeUnitAt(i)) return false;
  }
  return true;
}

int _readUint24LE(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);

int _readUint32BE(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _readUint16BE(Uint8List bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];
