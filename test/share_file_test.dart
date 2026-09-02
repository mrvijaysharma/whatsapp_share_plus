import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

void main() {
  group('ShareFile.fromPath', () {
    test('infers the MIME type and name from the path', () {
      final file = ShareFile.fromPath('/tmp/photos/holiday.JPG');
      expect(file.mimeType, 'image/jpeg');
      expect(file.name, 'holiday.JPG');
      expect(file.isImage, isTrue);
      expect(file.isInMemory, isFalse);
    });

    test('handles Windows-style separators', () {
      final file = ShareFile.fromPath(r'C:\Users\me\clip.mp4');
      expect(file.name, 'clip.mp4');
      expect(file.isVideo, isTrue);
    });

    test('lets an explicit MIME type win over the extension', () {
      final file = ShareFile.fromPath('/tmp/data.bin', mimeType: 'image/png');
      expect(file.mimeType, 'image/png');
    });

    test('leaves the MIME type null for an unknown extension', () {
      expect(ShareFile.fromPath('/tmp/archive.xyz').mimeType, isNull);
    });

    test('rejects an empty path', () {
      expect(
        () => ShareFile.fromPath('  '),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });
  });

  group('ShareFile.fromBytes', () {
    test('infers the MIME type from the name', () {
      final file = ShareFile.fromBytes(
        Uint8List.fromList(<int>[1, 2, 3]),
        name: 'invoice.pdf',
      );
      expect(file.mimeType, 'application/pdf');
      expect(file.isInMemory, isTrue);
    });

    test('rejects empty content', () {
      expect(
        () => ShareFile.fromBytes(Uint8List(0), name: 'empty.png'),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });

    test('rejects a missing name', () {
      expect(
        () => ShareFile.fromBytes(Uint8List.fromList(<int>[1]), name: ''),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });
  });

  group('ShareFile.fromXFile', () {
    test('carries the name and MIME type across', () {
      final file = ShareFile.fromXFile(
        XFile('/tmp/pick.png', mimeType: 'image/png', name: 'pick.png'),
      );
      expect(file.path, '/tmp/pick.png');
      expect(file.mimeType, 'image/png');
      expect(file.name, 'pick.png');
    });

    test('falls back to the extension when the XFile has no MIME type', () {
      final file = ShareFile.fromXFile(XFile('/tmp/pick.webp'));
      expect(file.mimeType, 'image/webp');
    });
  });

  group('lookupMimeType', () {
    test('is case insensitive', () {
      expect(lookupMimeType('SONG.MP3'), 'audio/mpeg');
    });

    test('returns null when there is no extension', () {
      expect(lookupMimeType('README'), isNull);
      expect(lookupMimeType('trailing.'), isNull);
    });

    test('covers the document types WhatsApp accepts', () {
      expect(lookupMimeType('a.pdf'), 'application/pdf');
      expect(lookupMimeType('a.docx'), contains('wordprocessingml'));
      expect(lookupMimeType('a.xlsx'), contains('spreadsheetml'));
    });
  });

  group('toMap', () {
    test('omits absent fields rather than sending nulls', () {
      final map = ShareFile.fromPath('/tmp/x.png').toMap();
      expect(map.containsKey('bytes'), isFalse);
      expect(map['path'], '/tmp/x.png');
    });
  });
}
