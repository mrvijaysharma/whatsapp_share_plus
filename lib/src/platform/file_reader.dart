export 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_io.dart'
    if (dart.library.js_interop) 'file_reader_web.dart';
