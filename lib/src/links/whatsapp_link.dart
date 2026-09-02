import '../models/whatsapp_target.dart';
import 'phone_number.dart';

/// Builders for WhatsApp's click-to-chat URLs.
///
/// Every method here is pure Dart with no platform dependency, so the links can
/// be built and unit tested anywhere — on a server, in a QR code, in an email,
/// or as the fallback path on platforms where no WhatsApp app is installed.
abstract final class WhatsAppLink {
  /// Builds a `https://wa.me` link, WhatsApp's canonical shareable URL.
  ///
  /// This is the link to put in emails, QR codes, and web pages: it opens the
  /// native app when one is installed and WhatsApp Web otherwise.
  ///
  /// [phone] is normalised with [WhatsAppPhoneNumber.normalize]; an
  /// unnormalisable number is dropped rather than sent in a broken form, which
  /// yields a link that opens WhatsApp's contact picker.
  static Uri chat({String? phone, String? text}) {
    final normalized = WhatsAppPhoneNumber.normalize(phone);
    return _build(
      'https://wa.me/${normalized ?? ''}',
      <String, String>{if (text != null && text.isNotEmpty) 'text': text},
    );
  }

  /// Builds a `https://api.whatsapp.com/send` link.
  ///
  /// Equivalent to [chat] but keeps the number in a query parameter, which some
  /// link-tracking and CRM tools handle more predictably.
  static Uri api({String? phone, String? text}) {
    final normalized = WhatsAppPhoneNumber.normalize(phone);
    return _build('https://api.whatsapp.com/send', <String, String>{
      if (normalized != null) 'phone': normalized,
      if (text != null && text.isNotEmpty) 'text': text,
    });
  }

  /// Builds a `https://web.whatsapp.com/send` link, which opens WhatsApp Web
  /// directly rather than routing through an app-detection page.
  ///
  /// Used as the browser fallback on desktop and web.
  static Uri web({String? phone, String? text}) {
    final normalized = WhatsAppPhoneNumber.normalize(phone);
    return _build('https://web.whatsapp.com/send', <String, String>{
      if (normalized != null) 'phone': normalized,
      if (text != null && text.isNotEmpty) 'text': text,
    });
  }

  /// Builds a `whatsapp://send` deep link that targets an installed app
  /// directly, bypassing the browser hop that [chat] takes.
  static Uri appScheme({
    String? phone,
    String? text,
    WhatsAppTarget target = WhatsAppTarget.standard,
  }) {
    final normalized = WhatsAppPhoneNumber.normalize(phone);
    return _build('${target.iosScheme}://send', <String, String>{
      if (normalized != null) 'phone': normalized,
      if (text != null && text.isNotEmpty) 'text': text,
    });
  }

  /// Builds the link that opens a WhatsApp Business catalog.
  ///
  /// [phone] is the business account's number.
  static Uri catalog({required String phone}) =>
      Uri.parse('https://wa.me/c/${WhatsAppPhoneNumber.parse(phone)}');

  /// Assembles a URL, percent-encoding each value.
  ///
  /// Built by hand rather than with [Uri]'s `queryParameters`, which encodes a
  /// space as `+`. WhatsApp renders that literally in the message body, so
  /// every value is encoded with `%20` instead.
  static Uri _build(String base, Map<String, String> parameters) {
    if (parameters.isEmpty) return Uri.parse(base);
    final query = parameters.entries
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return Uri.parse('$base?$query');
  }
}
