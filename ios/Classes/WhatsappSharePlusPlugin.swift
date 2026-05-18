import Flutter
import UIKit

public class WhatsappSharePlusPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "whatsapp_share_plus", binaryMessenger: registrar.messenger())
        let instance = WhatsappSharePlusPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isWhatsappInstalled":
            result(isAppInstalled(scheme: "whatsapp://"))
        case "isWhatsappBusinessInstalled":
            result(isAppInstalled(scheme: "whatsapp-business://"))

        case "shareToWhatsapp":
            shareTextToWhatsapp(call.arguments, isBusiness: false, result: result)
        case "shareToWhatsappBusiness":
            shareTextToWhatsapp(call.arguments, isBusiness: true, result: result)

        case "shareImageToWhatsapp":
            shareImageToWhatsapp(call.arguments, isBusiness: false, result: result)
        case "shareImageToWhatsappBusiness":
            shareImageToWhatsapp(call.arguments, isBusiness: true, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func isAppInstalled(scheme: String) -> Bool {
        guard let url = URL(string: scheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Text Sharing

    private func shareTextToWhatsapp(_ arguments: Any?, isBusiness: Bool, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any], let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text is required for text sharing", details: nil))
            return
        }

        let phone = args["phone"] as? String
        let scheme = isBusiness ? "whatsapp-business" : "whatsapp"
        var urlString: String

        if let phone = phone, !phone.isEmpty {
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "\(scheme)://send?phone=\(phone)&text=\(encodedText)"
        } else {
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "\(scheme)://send?text=\(encodedText)"
        }

        guard let whatsappURL = URL(string: urlString) else {
            result(FlutterError(code: "URL_ERROR", message: "Cannot create WhatsApp URL", details: nil))
            return
        }

        if UIApplication.shared.canOpenURL(whatsappURL) {
            UIApplication.shared.open(whatsappURL, options: [:]) { success in
                result(success)
            }
        } else {
            let appName = isBusiness ? "WhatsApp Business" : "WhatsApp"
            result(FlutterError(code: "APP_NOT_INSTALLED", message: "\(appName) is not installed", details: nil))
        }
    }

    // MARK: - Image Sharing

    private func shareImageToWhatsapp(_ arguments: Any?, isBusiness: Bool, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any], let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePath is required for image sharing", details: nil))
            return
        }

        // Validate file exists
        guard FileManager.default.fileExists(atPath: imagePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Image file not found at path: \(imagePath)", details: nil))
            return
        }

        // Note: phone is not supported for image sharing on iOS via UIDocumentInteractionController.
        // Note: WhatsApp Business image sharing uses the same share sheet as WhatsApp on iOS;
        //       the isBusiness flag uses the 'net.whatsapp.image' UTI which opens WhatsApp.
        //       Apple's UIDocumentInteractionController does not allow targeting a specific app reliably.
        if let phone = args["phone"] as? String, !phone.isEmpty {
            // Warn via debugPrint — cannot direct image to a specific contact on iOS
            debugPrint("[WhatsappSharePlus] Warning: 'phone' parameter is not supported for image sharing on iOS and will be ignored.")
        }

        let fileURL = URL(fileURLWithPath: imagePath)
        let docController = UIDocumentInteractionController(url: fileURL)
        // Use the standard WhatsApp UTI. WhatsApp Business will also appear in the share sheet.
        docController.uti = "net.whatsapp.image"

        DispatchQueue.main.async {
            guard let rootVC = UIApplication.topViewController() else {
                result(FlutterError(code: "NO_ROOT_VIEW_CONTROLLER", message: "Cannot find root view controller", details: nil))
                return
            }
            // presentOpenInMenu shows all apps that handle this UTI
            let presented = docController.presentOpenInMenu(
                from: rootVC.view.bounds,
                in: rootVC.view,
                animated: true
            )
            if presented {
                result(true)
            } else {
                result(FlutterError(code: "SHARE_FAILED", message: "Could not present share sheet. Ensure WhatsApp is installed.", details: nil))
            }
        }
    }
}

// MARK: - UIApplication Extension

extension UIApplication {
    class func topViewController(controller: UIViewController? = {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }()) -> UIViewController? {

        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
