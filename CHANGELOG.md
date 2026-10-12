# Changelog

All notable changes to this project are documented in this file.

## Unreleased

### Fixed

- **iOS sticker packs reached WhatsApp in a format it could not read.** The
  pasteboard payload was handed over as a dictionary, which iOS stores as a
  property list; WhatsApp expects JSON. The pack is now serialised with
  `JSONSerialization` before it is written.
- **iOS reported animated packs under the wrong key** (`is_animated_sticker_pack`
  instead of `animated_sticker_pack`), so WhatsApp treated every animated pack
  as static.

## [2.0.0] - 2026-09-10

A rewrite around a single `share()` call. **No existing code breaks**: every 1.x
method still works, deprecated, until 3.0.0. See [MIGRATION.md](MIGRATION.md).

### Added

- **`WhatsAppShare`**, replacing six overlapping methods with one `share()` call
  plus a `WhatsAppTarget` parameter.
- **Any file type** — video, audio, PDF, Office documents, and arbitrary files,
  alongside the images 1.x supported.
- **Multiple files in one share** (`ACTION_SEND_MULTIPLE` on Android, the system
  share sheet on iOS).
- **`ShareFile`** with three sources: `fromPath`, `fromBytes` (no temp file
  juggling), and `fromXFile` (what `image_picker` and `file_picker` return).
- **Web support** — `wa.me` links everywhere, plus file sharing through the Web
  Share API where the browser provides it.
- **macOS, Windows, and Linux support** — the desktop app where installed, and
  a browser fallback otherwise.
- **`WhatsAppShare.openChat()`** to open a conversation without an attachment.
  Works on every platform.
- **`WhatsAppShare.diagnose()`**, which reports host-app misconfiguration —
  missing `LSApplicationQueriesSchemes` entries, a `FileProvider` lost to
  manifest merging — instead of letting it surface as a wrong "not installed".
- **`WhatsAppLink`** and **`WhatsAppPhoneNumber`**: pure-Dart builders for
  `wa.me`, `api.whatsapp.com`, `web.whatsapp.com`, and catalog links, with
  phone-number normalisation. No plugin registration needed, so they work in
  server code, QR codes, and tests.
- **Sticker pack installation** on Android and iOS, with a validator that checks
  WhatsApp's requirements (512×512 WebP under 100 KB, 96×96 tray icon under
  50 KB, 3–30 stickers, no mixing animated and static) before WhatsApp rejects
  the pack without saying why.
- **Typed exceptions** under a `WhatsAppShareException` supertype:
  `WhatsAppNotInstalledException`, `InvalidShareArgumentException`,
  `ShareFileException`, `UnsupportedShareException`, `StickerPackException`,
  and `WhatsAppSharePlatformException`.
- **`ShareResult`** with a `ShareStatus`, distinguishing "WhatsApp opened",
  "the user picked a destination", "fell back to a link", and "the user
  dismissed the sheet".
- **`sharePositionOrigin`** to anchor share-sheet popovers on iPad and macOS.
- **`allowFallback`** to opt out of the `wa.me` fallback for text shares.
- **iOS and macOS privacy manifests** (`PrivacyInfo.xcprivacy`), declaring the
  file-timestamp API this plugin uses to prune its own cache.
- **Swift Package Manager support** on iOS and macOS, alongside the existing
  CocoaPods podspecs. Flutter now integrates plugins through Swift Package
  Manager by default and warns that a plugin without a manifest will eventually
  fail to build; both integrations compile the same sources.
- **Sanitised attachment names.** `ShareFile` lets callers name a file, so path
  separators and `..` are stripped on both Android and iOS before anything is
  written. 1.x derived names from the source file and had no such input.
- **New dependencies**: `cross_file` (for `ShareFile.fromXFile`), `web` (for the
  browser implementation, and the reason the package is WASM-ready), and
  `flutter_web_plugins` (to register the web implementation).

### Changed

- **Phone numbers are normalised and validated.** `+91 98765 43210`,
  `0091 98765 43210`, and `919876543210` all work; a number that cannot be
  international now raises `InvalidShareArgumentException` instead of silently
  opening a chat with nobody.
- **Android contact targeting for text now uses `wa.me`** rather than the
  undocumented `jid` intent extra, which was unreliable across WhatsApp
  versions. Attachments still use `jid`, since nothing else can address them.
- **Android shares run from the current activity** where one is attached,
  instead of always using the application context with
  `FLAG_ACTIVITY_NEW_TASK` — which put WhatsApp in a separate task and made the
  back gesture skip past the host app.
- **iOS picks a share mechanism from the payload.** A single media file with no
  caption uses WhatsApp's open-in menu; anything else uses the system share
  sheet, which — unlike 1.x — does carry a caption alongside an image.
- **iOS file shares now accept any installed WhatsApp app** rather than
  insisting the requested one was detected. iOS routes attachments through a
  share sheet where the user picks the destination anyway, and Business
  detection depends on an undocumented URL scheme — so requiring an exact match
  refused shares that would have worked. Text shares are unaffected: they still
  target the requested app and fall back to a `wa.me` link.
- **Raised requirements.** Flutter `>=3.22.0` (was `>=3.3.0`) and Dart
  `>=3.4.0` (was `>=3.0.0`), the latter for the sealed exception hierarchy.
  `plugin_platform_interface` moved to `^2.1.8`.
- **Android build toolchain.** The plugin's buildscript now declares Android
  Gradle Plugin 8.11.1 and Kotlin 2.2.20, which are the minimums Flutter 3.47
  enforces, and depends on `androidx.core:core` explicitly rather than relying
  on the Flutter embedding to supply `FileProvider` transitively. `minSdk`
  stays at 21 and `compileSdk` at 35, so the range of devices supported is
  unchanged. Apps on an older Gradle or AGP will need to upgrade alongside
  Flutter.

### Fixed

- **Android cache race.** 1.x deleted the entire share cache at the start of
  every share. WhatsApp reads a `content://` URI asynchronously, some time
  after the intent is delivered, so a second share within a few seconds could
  delete the file the first one was still reading. Shares now stage into
  per-share directories that are pruned by age.
- **Android intent construction.** The 1.x builder returned from inside an
  `apply` block and depended on a follow-up `hasExtra` check to notice. That
  check was correct, but the control flow made it easy to break; intent
  building now lives in `ShareIntentBuilder` with no early exits.
- **iOS multi-file and caption support.** 1.x could send neither; it dropped
  captions silently and had no path for a second file.
- **README documented an API that never existed** — `shareToWhatsapp` was shown
  with an `imagePath` parameter it does not take, and the package described
  itself as supporting multiple images, which it did not.
- **iOS `UIDocumentInteractionController` was released too early.** 1.x held it
  in a local variable, and UIKit keeps only a weak reference, so the menu could
  be deallocated before the user saw it. It is now retained until dismissal.
- **Android manifest declared a `package` attribute**, which Android Gradle
  Plugin 8 rejects.
- **Attachments sharing a filename could overwrite one another.** Two files
  named `image.jpg` in the same share landed in the same staging path on
  Android, iOS, and macOS, so only one survived to reach WhatsApp. Each
  attachment now stages into its own slot directory, keyed by position rather
  than name.
- **Android: a sticker pack add pending when the host activity was destroyed**
  (not merely backgrounded — a configuration change like rotation is
  unaffected) never resolved its Dart `Future`, leaking the call. It now
  completes with a `StickerPackException` when the activity is gone for good.
- **macOS: the sharing-picker anchor could go stale.** The window backing a
  held `NSView` reference can close between calls; the picker now falls back
  to the app's current key or main window rather than presenting from (or
  crashing on) a dead reference.
- **Android: `FileProvider` depended on a transitive `androidx.core`**
  version supplied by the Flutter embedding. It is now an explicit
  `androidx.core:core` dependency, so the plugin does not break if that
  transitive dependency ever changes.

## [1.0.3] - 2025-05-19

### Fixed

- **Critical (iOS)**: `shareImageToWhatsapp` and `shareImageToWhatsappBusiness`
  invoked the wrong method channel names, so image sharing always failed with
  "Text missing".
- **Android**: `getContext()` no longer force-unwraps; reports `NO_CONTEXT`
  instead of crashing.
- **Android**: file I/O moved to a background thread to prevent ANRs on large
  images.
- **Android**: added the missing `shareImageToWhatsapp` /
  `shareImageToWhatsappBusiness` channel cases.
- **Android**: `share()` validates that the image exists, returning
  `FILE_NOT_FOUND` rather than crashing.
- **iOS**: `shareImageToWhatsapp` checks the result of `presentOpenInMenu`.
- **iOS**: added the missing switch cases that caused
  `FlutterMethodNotImplemented`.
- **Tests**: replaced template tests for a non-existent `getPlatformVersion()`.
- **podspec**, **LICENSE**, **pubspec** metadata corrected.

### Added

- README section documenting the iOS limitations.

## [1.0.1] - Initial pub.dev releases

### Added

- Sharing text and images to WhatsApp and WhatsApp Business on Android and iOS.
- Null safety support and an example app.
