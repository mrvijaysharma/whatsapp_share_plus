import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

void main() {
  group('WhatsAppPhoneNumber.normalize', () {
    test('keeps a number that is already in WhatsApp form', () {
      expect(WhatsAppPhoneNumber.normalize('919876543210'), '919876543210');
    });

    test('strips the punctuation people actually type', () {
      expect(WhatsAppPhoneNumber.normalize('+91 98765-43210'), '919876543210');
      expect(WhatsAppPhoneNumber.normalize('(91) 98765 43210'), '919876543210');
      expect(WhatsAppPhoneNumber.normalize('+1 (555) 010-9999'), '15550109999');
    });

    test('strips the 00 international call prefix', () {
      expect(WhatsAppPhoneNumber.normalize('0091 98765 43210'), '919876543210');
    });

    test('rejects a national number with a trunk prefix', () {
      // A leading zero is a national prefix, never part of the international
      // form, and there is no way to guess the country code it is missing.
      expect(WhatsAppPhoneNumber.normalize('09876543210'), isNull);
    });

    test('rejects numbers outside the E.164 length range', () {
      expect(WhatsAppPhoneNumber.normalize('12345'), isNull);
      expect(WhatsAppPhoneNumber.normalize('1234567890123456'), isNull);
    });

    test('rejects input with no digits at all', () {
      expect(WhatsAppPhoneNumber.normalize('call me'), isNull);
      expect(WhatsAppPhoneNumber.normalize(''), isNull);
      expect(WhatsAppPhoneNumber.normalize(null), isNull);
    });

    test('parse throws where normalize returns null', () {
      expect(
        () => WhatsAppPhoneNumber.parse('09876543210'),
        throwsA(isA<InvalidShareArgumentException>()),
      );
    });
  });

  group('WhatsAppLink', () {
    test('builds a wa.me link with a normalised number', () {
      final uri = WhatsAppLink.chat(phone: '+91 98765 43210', text: 'Hi there');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Hi there');
    });

    test('encodes spaces as %20 rather than +', () {
      // WhatsApp renders a literal "+" in the message body, so the query has to
      // use percent-encoding for spaces.
      final uri = WhatsAppLink.chat(text: 'a b');
      expect(uri.toString(), contains('%20'));
      expect(uri.toString(), isNot(contains('+')));
    });

    test('omits the number when it cannot be normalised', () {
      final uri = WhatsAppLink.chat(phone: 'nonsense', text: 'Hi');
      expect(uri.path, '/');
    });

    test('builds an api.whatsapp.com link', () {
      final uri = WhatsAppLink.api(phone: '919876543210', text: 'Hi');
      expect(uri.host, 'api.whatsapp.com');
      expect(uri.queryParameters['phone'], '919876543210');
    });

    test('builds a web.whatsapp.com link', () {
      final uri = WhatsAppLink.web(phone: '919876543210');
      expect(uri.host, 'web.whatsapp.com');
      expect(uri.path, '/send');
    });

    test('builds an app-scheme link per target', () {
      expect(WhatsAppLink.appScheme(text: 'Hi').scheme, 'whatsapp');
      expect(
        WhatsAppLink.appScheme(text: 'Hi', target: WhatsAppTarget.business)
            .scheme,
        'whatsapp-business',
      );
    });

    test('builds a catalog link', () {
      expect(
        WhatsAppLink.catalog(phone: '919876543210').toString(),
        'https://wa.me/c/919876543210',
      );
    });

    test('encodes characters that would otherwise split the query', () {
      final uri = WhatsAppLink.chat(text: 'a&b=c?d#e');
      expect(uri.queryParameters['text'], 'a&b=c?d#e');
    });
  });
}
