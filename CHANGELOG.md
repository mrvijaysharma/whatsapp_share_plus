# Changelog

All notable changes to this project will be documented in this file.

## [1.0.3] - 2025-05-19
### Fixed
- **Critical (iOS)**: `shareImageToWhatsapp` and `shareImageToWhatsappBusiness` were invoking the wrong
  method channel names (`shareToWhatsapp` / `shareToWhatsappBusiness`) causing image sharing to
  always fail on iOS with "Text missing" error. Now correctly invokes `shareImageToWhatsapp` /
  `shareImageToWhatsappBusiness`.
- **Android**: `getContext()` no longer force-unwraps (`!!`) — safely returns `null` and reports a
  `NO_CONTEXT` error instead of crashing.
- **Android**: File I/O (image copy to cache) is now executed on a background thread via
  `Executors.newSingleThreadExecutor()` to prevent ANR on large images.
- **Android**: Added explicit method channel cases for `shareImageToWhatsapp` and
  `shareImageToWhatsappBusiness` to match the updated Dart method channel.
- **Android**: `share()` now validates that imagePath file exists before attempting to copy,
  returning a `FILE_NOT_FOUND` error instead of crashing.
- **iOS**: `shareImageToWhatsapp` now correctly checks the return value of
  `presentOpenInMenu` and returns a `SHARE_FAILED` error if the sheet could not be presented.
- **iOS**: Stale `shareImageToWhatsapp` / `shareImageToWhatsappBusiness` switch cases added to
  Swift plugin (previously missing, causing `FlutterMethodNotImplemented`).
- **README**: Fixed broken closing XML tag `</arra>` → `</array>` in iOS setup section.
- **Tests**: All Dart unit tests (whatsapp_share_plus_test.dart, method_channel_test.dart) and the
  Android Kotlin test were stale copy-pastes from the plugin template testing a non-existent
  `getPlatformVersion()` method. Replaced with real tests for all six plugin methods.
- **podspec**: Updated placeholder values (summary, description, homepage, author).
- **LICENSE**: Added full MIT License text (previously only contained the header line).
- **pubspec.yaml**: Relaxed SDK constraint from `^3.7.2` to `'>=3.0.0 <4.0.0'`.
- **Example app**: Replaced `print()` with `debugPrint()` in the catch block.

### Added
- **README**: Added "iOS Limitations" section documenting that `phone` is ignored for image
  sharing on iOS, and that WhatsApp Business image sharing opens a system share sheet.

## [1.0.1] - Initial pub.dev releases
### Added
- Initial releases on pub.dev (v1.0.1, v1.0.2).
- Support for sharing text and images to WhatsApp and WhatsApp Business on Android and iOS.
- Null safety support.
- Example app included.