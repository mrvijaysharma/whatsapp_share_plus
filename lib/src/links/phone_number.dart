import '../models/exceptions.dart';

/// Normalisation and validation for the phone numbers WhatsApp accepts.
///
/// WhatsApp addresses contacts by their full international number with no `+`,
/// no spaces, and no punctuation — `919876543210`, never `+91 98765 43210`.
/// Passing a number in any other shape silently opens a chat with nobody, so
/// this class converts the formats users actually type into the one form
/// WhatsApp understands.
abstract final class WhatsAppPhoneNumber {
  /// Shortest total length of a valid international number, per E.164.
  static const int minDigits = 7;

  /// Longest total length of a valid international number, per E.164.
  static const int maxDigits = 15;

  /// Converts [raw] into the digits-only form WhatsApp expects.
  ///
  /// Accepts the common human formats — `+91 98765-43210`, `(555) 010 9999`,
  /// `0091 98765 43210` — by stripping punctuation and the `00` international
  /// call prefix.
  ///
  /// Returns `null` when [raw] cannot be a valid international number. Callers
  /// that want an exception instead should use [parse].
  static String? normalize(String? raw) {
    if (raw == null) return null;

    var digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    // "00" is the international call prefix in much of the world; WhatsApp
    // wants the country code on its own. Only strip it when the number is long
    // enough that the remainder can still be a valid international number.
    if (digits.startsWith('00') && digits.length - 2 >= minDigits) {
      digits = digits.substring(2);
    }

    // A leading zero after the country code is a national trunk prefix and is
    // never part of the international form, but we cannot tell a trunk prefix
    // from a country code digit without a country database. Reject a leading
    // zero rather than guess wrong.
    if (digits.startsWith('0')) return null;

    if (digits.length < minDigits || digits.length > maxDigits) return null;

    return digits;
  }

  /// Whether [raw] can be normalised into a valid WhatsApp phone number.
  static bool isValid(String? raw) => normalize(raw) != null;

  /// Like [normalize], but throws [InvalidShareArgumentException] instead of
  /// returning `null`.
  static String parse(String raw) {
    final normalized = normalize(raw);
    if (normalized == null) {
      throw InvalidShareArgumentException(
        'Cannot read "$raw" as an international phone number. WhatsApp needs '
        'the full number including country code, digits only — for example '
        '919876543210 rather than +91 98765 43210 or 09876543210.',
        argument: 'phone',
      );
    }
    return normalized;
  }
}
