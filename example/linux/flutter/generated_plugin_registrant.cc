//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_linux/file_selector_plugin.h>
#include <whatsapp_share_plus/whatsapp_share_plus_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) whatsapp_share_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WhatsappSharePlusPlugin");
  whatsapp_share_plus_plugin_register_with_registrar(whatsapp_share_plus_registrar);
}
