import Flutter
import Foundation
import UIKit

/// Hands a sticker pack to WhatsApp on iOS.
///
/// iOS has no content provider equivalent, so WhatsApp reads sticker packs from
/// the system pasteboard: the publishing app writes a JSON payload under a
/// WhatsApp-specific pasteboard type, then opens `whatsapp://stickerPack`.
/// WhatsApp picks the payload up and asks the user to confirm.
///
/// The pasteboard item is written as local-only with a short expiry, so the
/// payload is never synced to the user's other devices and does not linger.
enum StickerPackPublisher {

    private static let pasteboardType = "net.whatsapp.third-party.sticker-pack"
    private static let stickerPackURL = URL(string: "whatsapp://stickerPack")!
    private static let payloadLifetime: TimeInterval = 60

    /// Publishes `pack` and opens WhatsApp.
    ///
    /// - Returns: `true` when WhatsApp was opened. iOS gives no callback for the
    ///   user's decision, so a `true` here means "WhatsApp received the pack",
    ///   not "the user installed it".
    static func publish(
        _ pack: [String: Any],
        completion: @escaping (Result<Bool, StickerPackError>) -> Void
    ) {
        guard UIApplication.shared.canOpenURL(stickerPackURL) else {
            completion(.failure(.whatsAppUnavailable))
            return
        }

        let payload: [String: Any]
        do {
            payload = try buildPayload(from: pack)
        } catch let error as StickerPackError {
            completion(.failure(error))
            return
        } catch {
            completion(.failure(.invalid(error.localizedDescription)))
            return
        }

        UIPasteboard.general.setItems(
            [[pasteboardType: payload]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(payloadLifetime),
            ]
        )

        UIApplication.shared.open(stickerPackURL, options: [:]) { opened in
            completion(opened ? .success(true) : .failure(.couldNotOpenWhatsApp))
        }
    }

    /// Builds the JSON payload in the shape WhatsApp expects.
    ///
    /// Image data goes in as base64 strings, which is what WhatsApp's own
    /// sample app writes and what its reader accepts.
    private static func buildPayload(from pack: [String: Any]) throws -> [String: Any] {
        guard let identifier = pack["identifier"] as? String, !identifier.isEmpty else {
            throw StickerPackError.invalid("A sticker pack requires an identifier.")
        }
        guard let trayImage = pack["trayImage"] as? [String: Any] else {
            throw StickerPackError.invalid("A sticker pack requires a tray image.")
        }
        guard let rawStickers = pack["stickers"] as? [[String: Any]], !rawStickers.isEmpty else {
            throw StickerPackError.invalid("A sticker pack requires at least one sticker.")
        }

        let stickers: [[String: Any]] = try rawStickers.enumerated().map { index, sticker in
            guard let image = sticker["image"] as? [String: Any] else {
                throw StickerPackError.invalid("Sticker \(index) has no image.")
            }
            var entry: [String: Any] = [
                "image_data": try base64(of: image).base64EncodedString(),
                "emojis": sticker["emojis"] as? [String] ?? [],
            ]
            if let accessibilityText = sticker["accessibilityText"] as? String {
                entry["accessibility_text"] = accessibilityText
            }
            return entry
        }

        var payload: [String: Any] = [
            "identifier": identifier,
            "name": pack["name"] as? String ?? identifier,
            "publisher": pack["publisher"] as? String ?? "",
            "tray_image": try base64(of: trayImage).base64EncodedString(),
            "stickers": stickers,
            "is_animated_sticker_pack": pack["animated"] as? Bool ?? false,
        ]

        // Optional metadata: only included when the caller supplied it, since
        // WhatsApp shows empty strings verbatim in its confirmation dialog.
        let optionalKeys = [
            ("publisherEmail", "publisher_email"),
            ("publisherWebsite", "publisher_website"),
            ("privacyPolicyWebsite", "privacy_policy_website"),
            ("licenseAgreementWebsite", "license_agreement_website"),
        ]
        for (source, destination) in optionalKeys {
            if let value = pack[source] as? String, !value.isEmpty {
                payload[destination] = value
            }
        }

        return payload
    }

    private static func base64(of image: [String: Any]) throws -> Data {
        if let typed = image["bytes"] as? FlutterStandardTypedData {
            return typed.data
        }
        if let data = image["bytes"] as? Data {
            return data
        }
        if let path = image["path"] as? String {
            guard let data = FileManager.default.contents(atPath: path) else {
                throw StickerPackError.invalid("Could not read sticker image at \(path).")
            }
            return data
        }
        throw StickerPackError.invalid("A sticker image needs either bytes or a path.")
    }
}

/// Failures specific to publishing a sticker pack.
enum StickerPackError: Error {
    case whatsAppUnavailable
    case couldNotOpenWhatsApp
    case invalid(String)

    /// The error code sent back to Dart.
    var code: String {
        switch self {
        case .whatsAppUnavailable: return "APP_NOT_INSTALLED"
        case .couldNotOpenWhatsApp: return "STICKER_PACK_ERROR"
        case .invalid: return "STICKER_PACK_INVALID"
        }
    }

    var message: String {
        switch self {
        case .whatsAppUnavailable:
            return "WhatsApp is not installed, or the 'whatsapp' scheme is missing from "
                + "LSApplicationQueriesSchemes in Info.plist."
        case .couldNotOpenWhatsApp:
            return "WhatsApp could not be opened to receive the sticker pack."
        case .invalid(let reason):
            return reason
        }
    }
}
