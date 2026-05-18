#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint whatsapp_share_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'whatsapp_share_plus'
  s.version          = '1.0.3'
  s.summary          = 'A Flutter plugin to share text and images to WhatsApp and WhatsApp Business on Android and iOS.'
  s.description      = <<-DESC
A Flutter plugin that allows sharing text, images, or both directly to WhatsApp and WhatsApp Business.
Supports targeting a specific phone number (contact) on both platforms.
Handles Android FileProvider setup and iOS URL scheme / UIDocumentInteractionController sharing.
                       DESC
  s.homepage         = 'https://github.com/mrvijaysharma/whatsapp_share_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vijay Sharma' => 'mrvijaysharma@github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'whatsapp_share_plus_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
