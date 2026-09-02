cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "whatsapp_share_plus")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must not be
# changed.
set(PLUGIN_NAME "whatsapp_share_plus_plugin")

add_library(${PLUGIN_NAME} SHARED
  "whatsapp_share_plus_plugin.cpp"
  "whatsapp_share_plus_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# shell32 provides ShellExecuteW for launching URLs; advapi32 provides the
# registry calls used to detect whether an app claims the whatsapp: protocol.
target_link_libraries(${PLUGIN_NAME} PRIVATE shell32 advapi32)

# List of absolute paths to libraries that should be bundled with the plugin.
set(whatsapp_share_plus_bundled_libraries
  ""
  PARENT_SCOPE
)
