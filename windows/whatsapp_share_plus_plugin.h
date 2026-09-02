#ifndef FLUTTER_PLUGIN_WHATSAPP_SHARE_PLUS_PLUGIN_H_
#define FLUTTER_PLUGIN_WHATSAPP_SHARE_PLUS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace whatsapp_share_plus {

// Windows implementation of the whatsapp_share_plus plugin.
//
// The WhatsApp desktop app registers the `whatsapp:` URL protocol, so text
// shares are handed to the shell as a URL. Windows offers no supported way for
// a desktop app to push a file into another app's compose window, so file
// shares report UNSUPPORTED_OPERATION rather than pretending to work.
class WhatsappSharePlusPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WhatsappSharePlusPlugin();

  virtual ~WhatsappSharePlusPlugin();

  // Disallow copy and assign.
  WhatsappSharePlusPlugin(const WhatsappSharePlusPlugin &) = delete;
  WhatsappSharePlusPlugin &operator=(const WhatsappSharePlusPlugin &) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace whatsapp_share_plus

#endif  // FLUTTER_PLUGIN_WHATSAPP_SHARE_PLUS_PLUGIN_H_
