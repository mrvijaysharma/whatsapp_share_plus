import 'dart:typed_data';

/// Reads a file from disk.
///
/// Resolved at compile time to a `dart:io` implementation on native platforms
/// and to a throwing stub on the web, where there is no file system to read.
Future<Uint8List> readFileBytes(String path) {
  throw UnsupportedError(
      'Reading files from disk is not supported on this platform.');
}

/// Whether the current platform can read files from disk.
bool get canReadFiles => false;
