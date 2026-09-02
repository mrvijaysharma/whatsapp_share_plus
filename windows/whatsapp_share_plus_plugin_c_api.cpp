#include "include/whatsapp_share_plus/whatsapp_share_plus_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "whatsapp_share_plus_plugin.h"

void WhatsappSharePlusPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  whatsapp_share_plus::WhatsappSharePlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
