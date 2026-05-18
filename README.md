# whatsapp_share_plus

A Flutter plugin to share text and images (including multiple images) directly to **WhatsApp** and **WhatsApp Business** on Android and iOS.

---

## Features

- Check if **WhatsApp** or **WhatsApp Business** is installed on the device.
- Share **text**, **images**, or **text with image** to WhatsApp or WhatsApp Business.
- Supports sharing to specific WhatsApp contacts via phone number.
- Handles Android file sharing efficiently using cache.
- Supports iOS sharing via native share sheet.
- Null safety compliant.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  whatsapp_share_plus:
    path: ../whatsapp_share_plus  # or from pub.dev when published
```

Import in your Dart code:

```dart
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
```
---

## Usage

Check if WhatsApp is installed:

```dart
bool isInstalled = await WhatsappSharePlus.isWhatsappInstalled();
```
Check if WhatsApp Business is installed:

```dart
bool isBusinessInstalled = await WhatsappSharePlus.isWhatsappBusinessInstalled();
```
Share text and/or image to WhatsApp:

```dart
await WhatsappSharePlus.shareToWhatsapp(
  text: "Hello from Flutter!",
  imagePath: "/path/to/image.jpg", // Optional
  phone: "1234567890",             // Optional phone with country code without '+'
);
```
Share text and/or image to WhatsApp Business:

```dart
await WhatsappSharePlus.shareToWhatsappBusiness(
  text: "Hello from Flutter Business!",
  imagePath: "/path/to/image.jpg", // Optional
  phone: "1234567890",             // Optional
);
```
---

## iOS Setup

Add the following to your ios/Runner/Info.plist:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>whatsapp-business</string>
</array>
```
---

## iOS Limitations

> [!IMPORTANT]
> Please read these limitations before using the plugin on iOS.

- **Image + Text together is not supported**: WhatsApp on iOS does not support sharing image and text simultaneously via the URL scheme or `UIDocumentInteractionController`. Share only image OR only text.
- **`phone` is ignored for image sharing**: When sharing an image on iOS, the `phone` parameter has no effect. To send a message to a specific contact, use `shareToWhatsapp` (text only) instead.
- **WhatsApp Business image sharing**: On iOS, image sharing opens a system share sheet where the user can manually select WhatsApp or WhatsApp Business. The plugin cannot programmatically force the image into WhatsApp Business specifically.
---

## Notes

- On iOS, sharing text and images together shows a warning because WhatsApp iOS does not support sharing text with image programmatically.

- On Android, the plugin handles copying image files to a cache folder to avoid permission issues and memory leaks.

- Always check if WhatsApp or WhatsApp Business is installed before sharing.
---

## License

MIT License
