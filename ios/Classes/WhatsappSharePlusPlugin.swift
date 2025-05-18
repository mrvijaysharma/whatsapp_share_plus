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
            shareToWhatsapp(call.arguments, isBusiness: false, result: result)
        case "shareToWhatsappBusiness":
            shareToWhatsapp(call.arguments, isBusiness: true, result: result)

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

    private func shareToWhatsapp(_ arguments: Any?, isBusiness: Bool, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any], let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text missing", details: nil))
            return
        }

        let phone = args["phone"] as? String
        var urlString: String

        if let phone = phone, !phone.isEmpty {
            // WhatsApp URL scheme for sending message to phone (no + sign)
            urlString = "whatsapp://send?phone=\(phone)&text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if isBusiness {
                urlString = "whatsapp-business://send?phone=\(phone)&text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
        } else {
            urlString = "whatsapp://send?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if isBusiness {
                urlString = "whatsapp-business://send?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
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
            result(false)
        }
    }

    private func shareImageToWhatsapp(_ arguments: Any?, isBusiness: Bool, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any], let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path missing", details: nil))
            return
        }

        let text = args["text"] as? String
        // phone is not used for image sharing via UIDocumentInteractionController

        let fileURL = URL(fileURLWithPath: imagePath)
        if !FileManager.default.fileExists(atPath: imagePath) {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Image file not found", details: nil))
            return
        }

        let docController = UIDocumentInteractionController(url: fileURL)
        docController.uti = "net.whatsapp.image"

        // WhatsApp Business doesn't have separate UTI or way to force it here on iOS, so just ignoring isBusiness

        DispatchQueue.main.async {
            if let rootVC = UIApplication.topViewController() {
                docController.presentOpenInMenu(from: rootVC.view.frame, in: rootVC.view, animated: true)
                result(true)
            } else {
                result(FlutterError(code: "NO_ROOT_VIEW_CONTROLLER", message: "Cannot find root view controller", details: nil))
            }
        }
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.connectedScenes
                                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                                    .first?.rootViewController) -> UIViewController? {
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
