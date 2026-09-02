import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelWhatsappSharePlus();
  const channel = MethodChannel('whatsapp_share_plus');

  final calls = <MethodCall>[];
  late Object? Function(MethodCall) respond;

  setUp(() {
    calls.clear();
    respond = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      final response = respond(call);
      if (response is PlatformException) throw response;
      return response;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('the wire protocol', () {
    test('sends the target with an install check', () async {
      respond = (_) => true;
      expect(await platform.isInstalled(WhatsAppTarget.business), isTrue);
      expect(calls.single.method, 'isInstalled');
      expect(calls.single.arguments, <String, Object?>{'target': 'business'});
    });

    test('parses the installed target list', () async {
      respond = (_) => <String>['standard', 'business'];
      expect(
        await platform.installedTargets(),
        <WhatsAppTarget>{WhatsAppTarget.standard, WhatsAppTarget.business},
      );
    });

    test('ignores target names it does not recognise', () async {
      respond = (_) => <String>['standard', 'something-new'];
      // An unknown name falls back to `standard`, so the set collapses to one.
      expect(await platform.installedTargets(), hasLength(1));
    });

    test('normalises the phone number before sending it', () async {
      respond = (_) => <String, Object?>{'status': 'opened'};
      await platform.share(
        const ShareRequest(text: 'Hi', phone: '+91 98765-43210'),
      );
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['phone'], '919876543210');
    });

    test('sends files as maps carrying path, name, and MIME type', () async {
      respond = (_) => <String, Object?>{'status': 'opened'};
      await platform.share(
        ShareRequest(files: <ShareFile>[ShareFile.fromPath('/tmp/photo.jpg')]),
      );

      final arguments = calls.single.arguments as Map<Object?, Object?>;
      final files = arguments['files']! as List<Object?>;
      final file = files.single! as Map<Object?, Object?>;
      expect(file['path'], '/tmp/photo.jpg');
      expect(file['name'], 'photo.jpg');
      expect(file['mimeType'], 'image/jpeg');
    });

    test('sends in-memory files as raw bytes', () async {
      respond = (_) => <String, Object?>{'status': 'opened'};
      await platform.share(
        ShareRequest(
          files: <ShareFile>[
            ShareFile.fromBytes(
              Uint8List.fromList(<int>[1, 2, 3]),
              name: 'note.pdf',
            ),
          ],
        ),
      );

      final arguments = calls.single.arguments as Map<Object?, Object?>;
      final file = (arguments['files']! as List<Object?>).single!
          as Map<Object?, Object?>;
      expect(file['bytes'], isA<Uint8List>());
      expect(file['mimeType'], 'application/pdf');
    });

    test('flattens the share position origin for the native side', () async {
      respond = (_) => <String, Object?>{'status': 'sheetPresented'};
      await platform.share(
        const ShareRequest(
          text: 'Hi',
          sharePositionOrigin: Rect.fromLTWH(1, 2, 3, 4),
        ),
      );

      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['sharePositionOrigin'], <String, double>{
        'left': 1,
        'top': 2,
        'width': 3,
        'height': 4,
      });
    });

    test('reads the status back out of the response', () async {
      respond = (_) => <String, Object?>{
            'status': 'fallback',
            'target': 'business',
            'message': 'Opened wa.me.',
          };
      final result = await platform.share(const ShareRequest(text: 'Hi'));
      expect(result.status, ShareStatus.fallback);
      expect(result.target, WhatsAppTarget.business);
      expect(result.usedFallback, isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('treats a dismissed sheet as unsuccessful', () async {
      respond = (_) => <String, Object?>{'status': 'dismissed'};
      final result = await platform.share(const ShareRequest(text: 'Hi'));
      expect(result.isSuccess, isFalse);
    });

    test('assumes the share opened when the native side says nothing',
        () async {
      respond = (_) => null;
      final result = await platform.share(const ShareRequest(text: 'Hi'));
      expect(result.status, ShareStatus.opened);
    });
  });

  group('error translation', () {
    test('maps APP_NOT_INSTALLED to a typed exception with the target',
        () async {
      respond = (_) => PlatformException(code: 'APP_NOT_INSTALLED');
      await expectLater(
        platform.share(
          const ShareRequest(text: 'Hi', target: WhatsAppTarget.business),
        ),
        throwsA(
          isA<WhatsAppNotInstalledException>()
              .having((e) => e.target, 'target', WhatsAppTarget.business),
        ),
      );
    });

    test('maps FILE_NOT_FOUND to a file exception', () async {
      respond = (_) => PlatformException(
            code: 'FILE_NOT_FOUND',
            message: 'Image file not found at path: /tmp/x.png',
          );
      await expectLater(
        platform.share(
          ShareRequest(files: <ShareFile>[ShareFile.fromPath('/tmp/x.png')]),
        ),
        throwsA(isA<ShareFileException>()),
      );
    });

    test('maps UNSUPPORTED_OPERATION to an unsupported exception', () async {
      respond = (_) => PlatformException(code: 'UNSUPPORTED_OPERATION');
      await expectLater(
        platform.share(const ShareRequest(text: 'Hi')),
        throwsA(isA<UnsupportedShareException>()),
      );
    });

    test('maps a sticker rejection to a sticker exception', () async {
      respond = (_) => PlatformException(
            code: 'STICKER_PACK_REJECTED',
            message: 'tray icon too large',
          );
      await expectLater(
        platform.addStickerPack(_validPack(), WhatsAppTarget.standard),
        throwsA(isA<StickerPackException>()),
      );
    });

    test('keeps the original code for errors it does not recognise', () async {
      respond =
          (_) => PlatformException(code: 'SOMETHING_ELSE', message: 'boom');
      await expectLater(
        platform.share(const ShareRequest(text: 'Hi')),
        throwsA(
          isA<WhatsAppSharePlatformException>()
              .having((e) => e.platformCode, 'platformCode', 'SOMETHING_ELSE'),
        ),
      );
    });

    test('explains a missing plugin implementation', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(
        platform.share(const ShareRequest(text: 'Hi')),
        throwsA(
          isA<UnsupportedShareException>().having(
            (e) => e.message,
            'message',
            contains('no implementation for this platform'),
          ),
        ),
      );
    });
  });

  group('diagnostics', () {
    test('parses a report with issues', () async {
      respond = (_) => <String, Object?>{
            'platform': 'android',
            'installedTargets': <String>['standard'],
            'issues': <Object?>[
              <String, Object?>{
                'code': 'MISSING_FILE_PROVIDER',
                'description': 'The FileProvider is not registered.',
                'remedy': 'Check the manifest merger output.',
              },
            ],
          };

      final report = await platform.diagnose();
      expect(report.platform, 'android');
      expect(
          report.installedTargets, <WhatsAppTarget>{WhatsAppTarget.standard});
      expect(report.isHealthy, isFalse);
      expect(report.issues.single.code, 'MISSING_FILE_PROVIDER');
      expect(report.toString(), contains('MISSING_FILE_PROVIDER'));
    });

    test('reports a healthy configuration', () async {
      respond = (_) => <String, Object?>{
            'platform': 'ios',
            'installedTargets': <String>['standard', 'business'],
            'issues': <Object?>[],
          };
      final report = await platform.diagnose();
      expect(report.isHealthy, isTrue);
      expect(report.toString(), contains('No configuration issues'));
    });
  });

  group('sticker packs', () {
    test('validates before touching the platform channel', () async {
      respond = (_) => true;
      await expectLater(
        platform.addStickerPack(
          StickerPack(
            identifier: '',
            name: 'Pack',
            publisher: 'Publisher',
            trayImage: ShareFile.fromBytes(
              Uint8List.fromList(<int>[0]),
              name: 'tray.png',
            ),
            stickers: const <Sticker>[],
          ),
          WhatsAppTarget.standard,
        ),
        throwsA(isA<StickerPackException>()),
      );
      expect(calls, isEmpty);
    });

    test('sends the target alongside the pack', () async {
      respond = (_) => true;
      expect(
        await platform.addStickerPack(_validPack(), WhatsAppTarget.business),
        isTrue,
      );
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['target'], 'business');
      expect(arguments['identifier'], 'demo');
    });
  });
}

/// A pack that passes validation, so tests can exercise what happens after it.
StickerPack _validPack() {
  Uint8List webp() {
    final bytes = Uint8List(30);
    bytes.setAll(0, 'RIFF'.codeUnits);
    bytes.setAll(8, 'WEBP'.codeUnits);
    bytes.setAll(12, 'VP8X'.codeUnits);
    bytes[16] = 10;
    for (final offset in <int>[24, 27]) {
      bytes[offset] = 511 & 0xFF;
      bytes[offset + 1] = (511 >> 8) & 0xFF;
    }
    return bytes;
  }

  Uint8List png() {
    final bytes = Uint8List(24);
    bytes.setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    bytes.setAll(12, 'IHDR'.codeUnits);
    bytes[19] = 96;
    bytes[23] = 96;
    return bytes;
  }

  return StickerPack(
    identifier: 'demo',
    name: 'Demo',
    publisher: 'Publisher',
    trayImage: ShareFile.fromBytes(png(), name: 'tray.png'),
    stickers: List<Sticker>.generate(
      3,
      (index) => Sticker(
        image: ShareFile.fromBytes(webp(), name: 'sticker_$index.webp'),
        emojis: const <String>['😀'],
      ),
    ),
  );
}
