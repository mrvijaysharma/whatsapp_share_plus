# Migrating to 2.0

Nothing breaks on upgrade. Every 1.x method still works, now marked deprecated,
and will keep working until 3.0.0. Migrate when it suits you.

## Why the API changed

1.x had six methods that multiplied along two axes — WhatsApp versus WhatsApp
Business, and text versus image. Adding video, documents, or multi-file support
would have meant six more, then twelve. 2.0 collapses them into one `share()`
call with a `target` parameter, so new capabilities become new arguments rather
than new methods.

The return type changed for the same reason. `Future<bool?>` could not express
the difference between "WhatsApp opened", "the user closed the share sheet", and
"WhatsApp is missing so we opened a browser" — all three arrived as `true`,
`null`, or an untyped `PlatformException`.

## Method mapping

| 1.x | 2.x |
|---|---|
| `WhatsappSharePlus.isWhatsappInstalled()` | `WhatsAppShare.isInstalled()` |
| `WhatsappSharePlus.isWhatsappBusinessInstalled()` | `WhatsAppShare.isInstalled(target: WhatsAppTarget.business)` |
| `WhatsappSharePlus.shareToWhatsapp(text: t, phone: p)` | `WhatsAppShare.share(text: t, phone: p)` |
| `WhatsappSharePlus.shareToWhatsappBusiness(text: t, phone: p)` | `WhatsAppShare.share(text: t, phone: p, target: WhatsAppTarget.business)` |
| `WhatsappSharePlus.shareImageToWhatsapp(imagePath: i, text: t)` | `WhatsAppShare.share(files: [ShareFile.fromPath(i)], text: t)` |
| `WhatsappSharePlus.shareImageToWhatsappBusiness(imagePath: i)` | `WhatsAppShare.share(files: [ShareFile.fromPath(i)], target: WhatsAppTarget.business)` |

## Handling results

```dart
// 1.x — three outcomes collapsed into one value
final ok = await WhatsappSharePlus.shareToWhatsapp(text: 'Hi');
if (ok == true) { /* ...but what happened? */ }

// 2.x
final result = await WhatsAppShare.share(text: 'Hi');
switch (result.status) {
  case ShareStatus.opened:         // WhatsApp opened with the payload
  case ShareStatus.sheetPresented: // the user picked a destination
  case ShareStatus.fallback:       // WhatsApp is missing; wa.me opened instead
  case ShareStatus.dismissed:      // the user closed the sheet
}
```

`ShareResult.isSuccess` is `true` for everything except `dismissed`, so
`if (result.isSuccess)` is the closest equivalent to the old `== true` check.

## Handling errors

1.x surfaced raw `PlatformException`s with string codes. 2.x throws typed
exceptions:

```dart
// 1.x
try {
  await WhatsappSharePlus.shareToWhatsapp(text: 'Hi');
} on PlatformException catch (e) {
  if (e.code == 'APP_NOT_INSTALLED') { /* ... */ }
}

// 2.x
try {
  await WhatsAppShare.share(text: 'Hi');
} on WhatsAppNotInstalledException catch (e) {
  showError('${e.target.displayName} is not installed');
} on InvalidShareArgumentException catch (e) {
  showError(e.message);
}
```

All of them share a `WhatsAppShareException` supertype, so a single
`on WhatsAppShareException` clause catches everything this package raises.

## Before you upgrade

**Check your toolchain.** 2.0 needs Flutter `>=3.22.0` and Dart `>=3.4.0`, up
from 3.3.0 and 3.0.0. The Dart floor is what allows the sealed exception
hierarchy you switch over below. On Android the plugin now builds against
Android Gradle Plugin 8.11.1 and Kotlin 2.2.20, matching what current Flutter
requires — if your app is on an older Gradle or AGP, upgrade it alongside
Flutter. `minSdk` is unchanged at 21, so you lose no devices.

## Behaviour changes to know about

**Phone numbers are validated.** 1.x passed whatever you gave it straight
through, so `09876543210` or `+91 98765 43210` silently opened a chat with
nobody. 2.x normalises the formats people type and throws
`InvalidShareArgumentException` for a number that cannot be international.
If you were pre-formatting numbers yourself, you can stop.

**Text-only shares fall back to `wa.me`.** When the target app is missing, a
text share now opens WhatsApp's web link instead of failing. Pass
`allowFallback: false` for the old behaviour. Shares with attachments still
throw, because a link cannot carry a file.

**iOS image sharing changed route.** 1.x always used
`UIDocumentInteractionController`, which silently ignored captions. 2.x uses it
only for a single media file with no caption, and otherwise opens the system
share sheet — which does carry the caption. If you were working around the old
limitation by sending two separate shares, you no longer need to.

**iOS attachments no longer require the exact app.** A file share now proceeds
whenever either WhatsApp app is installed, instead of failing when the
requested one was not detected. iOS shows a share sheet for attachments anyway,
so the user picks the destination; this mainly matters when targeting
`WhatsAppTarget.business`, whose detection on iOS is best-effort. Text shares
still target the app you asked for.

**iPad needs an anchor.** Pass `sharePositionOrigin` when sharing files, or the
popover appears in the corner. This was a latent problem in 1.x too.

**The platform interface gained methods.** This only affects you if you wrote a
custom `WhatsappSharePlusPlatform` implementation or a test double using
`implements`. Add `isInstalled`, `installedTargets`, `share`, `openChat`,
`diagnose`, `addStickerPack`, and `isStickerPackSupported`; the 1.x methods now
have default implementations on the interface.

## New in 2.0

- Video, audio, PDF, and arbitrary document sharing
- Multiple files in one share
- `ShareFile.fromBytes` and `ShareFile.fromXFile`
- Web, macOS, Windows, and Linux support
- `WhatsAppShare.openChat()`
- `WhatsAppShare.diagnose()` for configuration problems
- `WhatsAppLink` and `WhatsAppPhoneNumber` — pure Dart, usable anywhere
- Sticker pack installation with validation
- `sharePositionOrigin` for iPad and macOS
