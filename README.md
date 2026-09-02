# whatsapp_share_plus

Share text, images, video, audio, and documents to **WhatsApp** and **WhatsApp Business** from Flutter — on Android, iOS, web, macOS, Windows, and Linux.

[![pub package](https://img.shields.io/pub/v/whatsapp_share_plus.svg)](https://pub.dev/packages/whatsapp_share_plus)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

```dart
await WhatsAppShare.share(
  text: 'Here is the invoice.',
  files: [ShareFile.fromPath('/tmp/invoice.pdf')],
  phone: '+91 98765 43210',
);
```

---

## What it does

- **Send anything WhatsApp accepts** — text, photos, video, audio, PDFs and other documents, several files at once.
- **Address a contact by phone number**, in whatever format your users type it (`+91 98765 43210`, `0091…`, `919876543210`).
- **Target WhatsApp or WhatsApp Business** explicitly.
- **Install sticker packs** into WhatsApp, with WhatsApp's own constraints checked before you ship a pack that would be silently rejected.
- **Build `wa.me` links** in pure Dart, for QR codes, emails, and server-side code.
- **Diagnose setup problems** rather than reporting "WhatsApp is not installed" when it plainly is.
- **Typed errors** — you can tell a missing app from an unreadable file from a bad phone number.

---

## Platform support

WhatsApp exposes different capabilities on each platform, and this package does not pretend otherwise. What actually works:

| | Android | iOS | Web | macOS | Windows | Linux |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Share text | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Share to a specific contact | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Share one file | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ❌ |
| Share several files | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ |
| File **and** caption together | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | ❌ |
| File **to a specific contact** | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Detect installed apps | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Install sticker packs | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

✅ works directly · ⚠️ works through a share sheet or with caveats · ❌ not possible

The caveats, in full:

- **iOS** cannot push a file into a named app. A single photo, video, or audio clip with no caption goes through WhatsApp's own open-in menu, which lists only WhatsApp. Anything else — several files, a document, or a file with a caption — opens the system share sheet, where the user picks WhatsApp.
- **Detecting WhatsApp Business on iOS is best-effort.** It relies on the `whatsapp-business://` URL scheme, which WhatsApp does not formally document. If a future release stops registering it, `isInstalled(target: WhatsAppTarget.business)` reports `false` even though the app is there. Sharing still works: text falls back to a `wa.me` link, and files open the share sheet as long as either WhatsApp app is installed. Do not gate your UI on this check alone.
- **Attachments cannot be addressed to a contact** anywhere except Android, and even there WhatsApp's mechanism for it is undocumented: when it is honoured the file goes straight to that chat, and when it is not the user gets WhatsApp's contact picker with the file already attached.
- **Web** shares files through the browser's Web Share API, which today means Chrome and Safari on mobile. Files must be built with `ShareFile.fromBytes` — a browser has no file system to read paths from. Text sharing works in every browser.
- **macOS** opens the WhatsApp desktop app for text, and routes files through the macOS share picker.
- **Windows and Linux** open the desktop app or WhatsApp Web for text. Neither OS offers a supported way to place a file into another app's compose window, so file shares raise `UnsupportedShareException` rather than failing quietly.
- **Everywhere**, if the app is missing, a text share falls back to a `wa.me` link that opens WhatsApp Web. Pass `allowFallback: false` to get a `WhatsAppNotInstalledException` instead.

---

## Install

```yaml
dependencies:
  whatsapp_share_plus: ^2.0.0
```

### iOS setup (required)

iOS refuses to say whether an app is installed unless you declare the URL schemes up front. Without this, `isInstalled()` always returns `false` and shares fall back to the browser. Add to `ios/Runner/Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>whatsapp-business</string>
</array>
```

### macOS setup

Sandboxed macOS apps need outgoing network access to open a URL. In `macos/Runner/*.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Android setup

None. The plugin contributes its own `<queries>` entries, `FileProvider`, and sticker provider through manifest merging.

---

## Usage

### Check what's installed

```dart
if (await WhatsAppShare.isInstalled()) { /* WhatsApp is present */ }

final installed = await WhatsAppShare.installedTargets();
// => {WhatsAppTarget.standard, WhatsAppTarget.business}
```

### Share text

```dart
await WhatsAppShare.share(text: 'Hello from Flutter');
```

### Share to a specific contact

Any format your users type is accepted; the number is normalised for you.

```dart
await WhatsAppShare.share(
  text: 'Your order has shipped.',
  phone: '+91 98765 43210',
);
```

### Share files

```dart
final photos = await ImagePicker().pickMultiImage();

await WhatsAppShare.share(
  text: 'Holiday photos',
  files: photos.map(ShareFile.fromXFile).toList(),
);
```

From a path, from memory, or from an `XFile`:

```dart
ShareFile.fromPath('/tmp/invoice.pdf');
ShareFile.fromBytes(pdfBytes, name: 'invoice.pdf');
ShareFile.fromXFile(await ImagePicker().pickImage(source: ImageSource.camera));
```

Prefer paths for large media — byte-backed files are copied across the platform channel.

### Target WhatsApp Business

```dart
await WhatsAppShare.share(
  text: 'Your table is ready.',
  target: WhatsAppTarget.business,
);
```

### iPad and macOS

Share sheets on iPad and Mac are popovers and must be anchored to the control that opened them, or they appear in the corner pointing at nothing:

```dart
final box = context.findRenderObject() as RenderBox;

await WhatsAppShare.share(
  files: files,
  sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
);
```

### Open a chat without attaching anything

Works on every platform, including web.

```dart
await WhatsAppShare.openChat(phone: '919876543210', text: 'Hi!');
```

### Handle the outcome

`ShareResult` distinguishes outcomes a `bool` cannot:

```dart
final result = await WhatsAppShare.share(text: 'Hello');

switch (result.status) {
  case ShareStatus.opened:         // WhatsApp opened with the payload
  case ShareStatus.sheetPresented: // the user picked a destination
  case ShareStatus.fallback:       // opened wa.me in a browser
  case ShareStatus.dismissed:      // the user closed the sheet
}
```

`ShareStatus.opened` means WhatsApp opened with your content loaded. No WhatsApp API reports whether the user actually pressed send, and any package claiming otherwise is guessing.

### Handle errors

Every failure is a `WhatsAppShareException` subtype:

```dart
try {
  await WhatsAppShare.share(text: 'Hello', phone: userInput);
} on WhatsAppNotInstalledException catch (e) {
  showError('${e.target.displayName} is not installed');
} on InvalidShareArgumentException catch (e) {
  showError(e.message);          // e.g. a phone number missing its country code
} on ShareFileException catch (e) {
  showError('Could not read ${e.path}');
} on UnsupportedShareException catch (e) {
  showError(e.message);          // e.g. attaching files on Windows
}
```

### Diagnose configuration problems

Most "WhatsApp is not installed" reports are really a missing `Info.plist` entry or a stripped Android `<queries>` tag. Rather than guessing:

```dart
if (kDebugMode) {
  debugPrint((await WhatsAppShare.diagnose()).toString());
}
```

```
WhatsApp Share diagnostics (ios)
  Installed: WhatsApp
  [MISSING_QUERY_SCHEME] Info.plist does not declare the 'whatsapp-business'
    URL scheme, so WhatsApp Business is reported as missing even when installed.
    Fix: Add 'whatsapp-business' to the LSApplicationQueriesSchemes array in
    ios/Runner/Info.plist.
```

### Build links without the plugin

`WhatsAppLink` is pure Dart — no plugin registration, no platform channel. Use it for QR codes, emails, server-side code, and tests.

```dart
WhatsAppLink.chat(phone: '+91 98765 43210', text: 'Hi');
// https://wa.me/919876543210?text=Hi

WhatsAppLink.web(phone: '919876543210');      // web.whatsapp.com/send?phone=…
WhatsAppLink.api(phone: '919876543210');      // api.whatsapp.com/send?phone=…
WhatsAppLink.catalog(phone: '919876543210');  // wa.me/c/919876543210

WhatsAppPhoneNumber.normalize('+91 98765-43210'); // 919876543210
WhatsAppPhoneNumber.isValid('09876543210');       // false — trunk prefix
```

### Install a sticker pack

WhatsApp rejects malformed packs without explaining why, so packs are validated first — 512×512 WebP stickers under 100 KB, a 96×96 tray icon under 50 KB, 3 to 30 stickers, and no mixing animated with static.

```dart
final pack = StickerPack(
  identifier: 'my-app-pack-1',
  name: 'Office Cats',
  publisher: 'Acme Inc',
  trayImage: ShareFile.fromBytes(trayBytes, name: 'tray.png'),
  stickers: [
    for (final sticker in stickerBytes)
      Sticker(
        image: ShareFile.fromBytes(sticker, name: 'cat.webp'),
        emojis: ['🐱'],
      ),
  ],
);

final problems = await pack.validate();
if (problems.isNotEmpty) {
  debugPrint(problems.join('\n'));  // fix these before shipping
  return;
}

final added = await WhatsAppShare.addStickerPack(pack);
```

WhatsApp asks the user to confirm. On Android `added` reflects their answer; on iOS the decision is not reported back, so `true` there means WhatsApp received the pack.

---

## Migrating from 1.x

Your existing code still compiles — the 1.x methods are deprecated but intact until 3.0.0. See [MIGRATION.md](MIGRATION.md) for the mapping.

```dart
// 1.x
await WhatsappSharePlus.shareImageToWhatsapp(imagePath: path, text: 'Hi');

// 2.x
await WhatsAppShare.share(files: [ShareFile.fromPath(path)], text: 'Hi');
```

---

## Contributing

Issues and pull requests are welcome at
[github.com/mrvijaysharma/whatsapp_share_plus](https://github.com/mrvijaysharma/whatsapp_share_plus).

This package is not affiliated with or endorsed by WhatsApp or Meta.

## License

MIT — see [LICENSE](LICENSE).
