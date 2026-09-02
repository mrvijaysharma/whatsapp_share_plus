import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import 'exceptions.dart';

/// A single attachment to send to WhatsApp.
///
/// A file can come from a path on disk ([ShareFile.fromPath]), from an
/// in-memory buffer ([ShareFile.fromBytes]), or from an [XFile] as returned by
/// `image_picker` and `file_picker` ([ShareFile.fromXFile]).
///
/// Prefer path-based files for large media: byte-based files are copied across
/// the platform channel, so a large video costs an extra full-size copy.
class ShareFile {
  const ShareFile._({
    this.path,
    this.bytes,
    this.mimeType,
    this.name,
  });

  /// Creates a file backed by an existing file on disk.
  ///
  /// [mimeType] is inferred from the extension when omitted. Supplying it
  /// explicitly matters when the extension is missing or misleading, because
  /// WhatsApp picks its composer (photo, video, document) from the MIME type.
  factory ShareFile.fromPath(
    String path, {
    String? mimeType,
    String? name,
  }) {
    if (path.trim().isEmpty) {
      throw const InvalidShareArgumentException(
        'A share file path must not be empty.',
        argument: 'path',
      );
    }
    return ShareFile._(
      path: path,
      mimeType: mimeType ?? lookupMimeType(path),
      name: name ?? _basename(path),
    );
  }

  /// Creates a file from an in-memory buffer.
  ///
  /// [name] must include an extension (for example `receipt.pdf`) — WhatsApp
  /// relies on it to label the attachment and to choose an icon.
  factory ShareFile.fromBytes(
    Uint8List bytes, {
    required String name,
    String? mimeType,
  }) {
    if (bytes.isEmpty) {
      throw const InvalidShareArgumentException(
        'A share file must not be empty.',
        argument: 'bytes',
      );
    }
    if (name.trim().isEmpty) {
      throw const InvalidShareArgumentException(
        'A byte-backed share file requires a name with a file extension.',
        argument: 'name',
      );
    }
    return ShareFile._(
      bytes: bytes,
      name: name,
      mimeType: mimeType ?? lookupMimeType(name),
    );
  }

  /// Creates a file from an [XFile], the type returned by `image_picker`,
  /// `file_picker`, and `camera`.
  factory ShareFile.fromXFile(XFile file, {String? mimeType}) {
    return ShareFile.fromPath(
      file.path,
      mimeType: mimeType ?? file.mimeType ?? lookupMimeType(file.path),
      name: file.name.isEmpty ? _basename(file.path) : file.name,
    );
  }

  /// Absolute path to the file on disk, or `null` for byte-backed files.
  final String? path;

  /// The file contents, or `null` for path-backed files.
  final Uint8List? bytes;

  /// The MIME type WhatsApp should use to interpret this file.
  final String? mimeType;

  /// The display name, including extension.
  final String? name;

  /// Whether this file carries its contents in memory rather than on disk.
  bool get isInMemory => bytes != null;

  /// Whether WhatsApp will treat this file as a photo.
  bool get isImage => mimeType?.startsWith('image/') ?? false;

  /// Whether WhatsApp will treat this file as a video.
  bool get isVideo => mimeType?.startsWith('video/') ?? false;

  /// Whether WhatsApp will treat this file as an audio clip.
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;

  /// Serialises this file for transport across the platform channel.
  Map<String, Object?> toMap() => <String, Object?>{
        if (path != null) 'path': path,
        if (bytes != null) 'bytes': bytes,
        if (mimeType != null) 'mimeType': mimeType,
        if (name != null) 'name': name,
      };

  @override
  String toString() =>
      'ShareFile(${isInMemory ? 'bytes: ${bytes!.length}' : 'path: $path'}, '
      'mimeType: $mimeType)';

  static String _basename(String path) {
    final separator = path.lastIndexOf(RegExp(r'[/\\]'));
    return separator == -1 ? path : path.substring(separator + 1);
  }
}

/// Infers a MIME type from a file name or path.
///
/// Returns `null` when the extension is unknown, which callers should treat as
/// "send as a generic document".
String? lookupMimeType(String pathOrName) {
  final dot = pathOrName.lastIndexOf('.');
  if (dot == -1 || dot == pathOrName.length - 1) return null;
  final extension = pathOrName.substring(dot + 1).toLowerCase();
  return _mimeTypes[extension];
}

/// Extension-to-MIME map covering the formats WhatsApp accepts.
///
/// Deliberately small: an unknown extension resolves to `null`, which the
/// native side sends as `application/octet-stream` (a generic document).
const Map<String, String> _mimeTypes = <String, String>{
  // Images.
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'tif': 'image/tiff',
  'tiff': 'image/tiff',
  // Video.
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'mkv': 'video/x-matroska',
  '3gp': 'video/3gpp',
  'webm': 'video/webm',
  // Audio.
  'mp3': 'audio/mpeg',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'opus': 'audio/opus',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'amr': 'audio/amr',
  // Documents.
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'rtf': 'application/rtf',
  'zip': 'application/zip',
  'json': 'application/json',
  'xml': 'application/xml',
};
