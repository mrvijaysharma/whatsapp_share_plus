import 'dart:io';
import 'dart:typed_data';

/// Reads a file from disk using `dart:io`.
Future<Uint8List> readFileBytes(String path) => File(path).readAsBytes();

/// Native platforms always have a readable file system.
bool get canReadFiles => true;
