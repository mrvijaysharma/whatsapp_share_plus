/// Share text, images, video, and documents to WhatsApp and WhatsApp Business.
///
/// The entry point is [WhatsAppShare]:
///
/// ```dart
/// import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
///
/// await WhatsAppShare.share(
///   text: 'Look at this',
///   files: [ShareFile.fromPath(photo.path)],
///   phone: '+91 98765 43210',
/// );
/// ```
///
/// For links that work anywhere — QR codes, emails, web pages — use
/// [WhatsAppLink], which is pure Dart and needs no plugin registration.
library;

export 'src/legacy/whatsapp_share_plus_legacy.dart';
export 'src/links/phone_number.dart';
export 'src/links/whatsapp_link.dart';
export 'src/models/diagnostics.dart';
export 'src/models/exceptions.dart';
export 'src/models/image_header.dart' show ImageHeader, parseImageHeader;
export 'src/models/share_file.dart' show ShareFile, lookupMimeType;
export 'src/models/share_request.dart';
export 'src/models/share_result.dart';
export 'src/models/sticker_pack.dart';
export 'src/models/whatsapp_target.dart';
export 'src/whatsapp_share.dart';
