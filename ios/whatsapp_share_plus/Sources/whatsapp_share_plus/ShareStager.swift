import Flutter
import Foundation
import UIKit

/// A file copied into a temporary directory, ready to hand to a share sheet.
struct StagedFile {
    let url: URL
    let mimeType: String
}

/// Copies the files a caller wants to share into a private temporary directory.
///
/// Two reasons the originals cannot be used directly: a caller may pass a path
/// inside a directory that disappears (an `image_picker` result, for example),
/// and routing a file straight to WhatsApp requires renaming it to an extension
/// WhatsApp claims. Both need a copy.
enum ShareStager {

    /// Extensions WhatsApp registers for its own uniform type identifiers.
    ///
    /// Giving a file one of these extensions and the matching UTI narrows
    /// `UIDocumentInteractionController` down to WhatsApp alone, instead of
    /// showing the full share sheet.
    private static let whatsAppTypes: [(prefix: String, uti: String, ext: String)] = [
        ("image/", "net.whatsapp.image", "wai"),
        ("video/", "net.whatsapp.movie", "wam"),
        ("audio/", "net.whatsapp.audio", "waa"),
    ]

    /// The WhatsApp UTI for [mimeType], or `nil` when WhatsApp claims no type
    /// for it — documents, for instance, which must go through the share sheet.
    static func whatsAppUTI(for mimeType: String) -> String? {
        whatsAppTypes.first { mimeType.hasPrefix($0.prefix) }?.uti
    }

    private static func whatsAppExtension(for mimeType: String) -> String? {
        whatsAppTypes.first { mimeType.hasPrefix($0.prefix) }?.ext
    }

    /// Copies `files` — the raw `ShareFile` maps from Dart — into a fresh
    /// session directory.
    ///
    /// - Parameter useWhatsAppExtension: when `true`, media files are renamed to
    ///   WhatsApp's private extensions so the open-in menu resolves to WhatsApp.
    /// - Throws: `ShareStagerError` when a source file is missing or unreadable.
    static func stage(
        _ files: [[String: Any]],
        useWhatsAppExtension: Bool = false
    ) throws -> [StagedFile] {
        guard !files.isEmpty else { return [] }

        let session = FileManager.default.temporaryDirectory
            .appendingPathComponent("whatsapp_share_plus", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: session,
            withIntermediateDirectories: true
        )

        return try files.enumerated().map { index, raw in
            let mimeType = raw["mimeType"] as? String ?? "application/octet-stream"
            let requestedName = (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            var fileName = sanitize(requestedName ?? "attachment_\(index)")

            if useWhatsAppExtension, let ext = whatsAppExtension(for: mimeType) {
                fileName = (fileName as NSString).deletingPathExtension + "." + ext
            }

            // Each attachment gets its own numbered slot inside the session.
            // Two camera-roll picks routinely share a basename, and staging
            // both directly into the session directory would hand the share
            // sheet the same URL twice — sending one file twice and silently
            // dropping the other. Slotting keeps the visible name intact.
            let slot = session.appendingPathComponent(String(index), isDirectory: true)
            try FileManager.default.createDirectory(
                at: slot,
                withIntermediateDirectories: true
            )
            let destination = slot.appendingPathComponent(fileName)

            if let data = raw["bytes"] as? FlutterStandardTypedData {
                try data.data.write(to: destination)
            } else if let bytes = raw["bytes"] as? Data {
                try bytes.write(to: destination)
            } else if let path = raw["path"] as? String {
                guard FileManager.default.fileExists(atPath: path) else {
                    throw ShareStagerError.fileNotFound(path)
                }
                try FileManager.default.copyItem(
                    at: URL(fileURLWithPath: path),
                    to: destination
                )
            } else {
                throw ShareStagerError.malformed(
                    "A share file must carry either a path or bytes."
                )
            }

            return StagedFile(url: destination, mimeType: mimeType)
        }
    }

    /// Removes staged directories left over from previous shares.
    ///
    /// Called before staging rather than after sharing, because iOS reads the
    /// file asynchronously once the share sheet takes over.
    static func pruneOldSessions(olderThan maxAge: TimeInterval = 3600) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("whatsapp_share_plus", isDirectory: true)
        guard let sessions = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-maxAge)
        for session in sessions {
            let modified = (try? session.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, modified < cutoff {
                try? FileManager.default.removeItem(at: session)
            }
        }
    }

    private static func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "..", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "attachment" : cleaned
    }
}

/// Errors raised while preparing files for a share.
enum ShareStagerError: Error {
    case fileNotFound(String)
    case malformed(String)

    /// The error code sent back to Dart, matched by the method channel.
    var code: String {
        switch self {
        case .fileNotFound: return "FILE_NOT_FOUND"
        case .malformed: return "FILE_ERROR"
        }
    }

    var message: String {
        switch self {
        case .fileNotFound(let path): return "Image file not found at path: \(path)"
        case .malformed(let reason): return reason
        }
    }
}
