/// Identifies which WhatsApp application a share should be routed to.
///
/// WhatsApp ships two separate consumer apps. They are distinct installs with
/// distinct data, so a device may have either, both, or neither.
enum WhatsAppTarget {
  /// The consumer WhatsApp Messenger app.
  standard(
    androidPackage: 'com.whatsapp',
    iosScheme: 'whatsapp',
    displayName: 'WhatsApp',
  ),

  /// The WhatsApp Business app.
  ///
  /// On iOS this target is best-effort: see [iosScheme] for the caveat.
  business(
    androidPackage: 'com.whatsapp.w4b',
    iosScheme: 'whatsapp-business',
    displayName: 'WhatsApp Business',
  );

  const WhatsAppTarget({
    required this.androidPackage,
    required this.iosScheme,
    required this.displayName,
  });

  /// The Android application id, used for `Intent.setPackage` and for
  /// package-visibility queries on Android 11 and above.
  final String androidPackage;

  /// The iOS URL scheme, without the `://` suffix.
  ///
  /// The scheme for [WhatsAppTarget.business] is not part of any documented,
  /// guaranteed contract. If WhatsApp Business does not register it on the
  /// user's iOS version, detection reports the app as missing and shares fall
  /// back to the system share sheet, where the user can pick the app manually.
  final String iosScheme;

  /// A human-readable name suitable for surfacing in error messages and UI.
  final String displayName;

  /// The platform channel token for this target.
  String get wireName => name;

  /// Parses a [wireName] produced by [WhatsAppTarget.wireName].
  static WhatsAppTarget fromWireName(String value) {
    return WhatsAppTarget.values.firstWhere(
      (target) => target.wireName == value,
      orElse: () => WhatsAppTarget.standard,
    );
  }
}
