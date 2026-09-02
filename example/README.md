# whatsapp_share_plus example

A small app exercising every part of the plugin.

## Running it

```bash
flutter run
```

Works on Android, iOS, web, macOS, Windows, and Linux. What you can do varies by
platform — see the support table in the [package README](../README.md).

## What it demonstrates

- **Detecting installed apps** — the card at the top reflects
  `WhatsAppShare.installedTargets()`.
- **Choosing a target** — the segmented control switches between WhatsApp and
  WhatsApp Business.
- **Text, files, and captions** — pick images with `image_picker`, convert them
  with `ShareFile.fromXFile`, and send them with an optional caption.
- **Contact targeting** — type a number in any format; the plugin normalises it.
- **Opening a chat** without an attachment, which works on every platform.
- **Diagnostics** — the shield icon in the app bar runs
  `WhatsAppShare.diagnose()` and shows what it finds. Start here if a share
  behaves unexpectedly.
- **Link building** — the card at the bottom shows the `wa.me` link for the
  current input, built with `WhatsAppLink` in pure Dart.
- **Error handling** — `_run()` in `lib/main.dart` catches each exception type
  separately; it is the pattern worth copying into a real app.

## Before you run on iOS

The example's `Info.plist` already declares the URL schemes. Your own app needs
them too, or `isInstalled()` always reports `false`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>whatsapp-business</string>
</array>
```

## Integration tests

```bash
flutter test integration_test
```

These run against a real device or simulator. They check that the platform
channel is wired up and that input validation happens before anything reaches
the native side. Sharing itself is not asserted: every share hands control to
another app, which a test cannot drive or return from.
