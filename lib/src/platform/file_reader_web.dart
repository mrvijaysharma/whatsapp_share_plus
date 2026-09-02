import 'dart:typed_data';

/// The web has no file system path to read from; byte-backed [ShareFile]s must
/// be used instead.
Future<Uint8List> readFileBytes(String path) {
  throw UnsupportedError(
    'Reading a file by path is not supported on the web. '
    'Use ShareFile.fromBytes instead.',
  );
}

/// The web cannot read files by path.
bool get canReadFiles => false;
