#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'whatsapp_share_plus'
  s.version          = '2.0.0'
  s.summary          = 'Share text, media, and documents to WhatsApp and WhatsApp Business.'
  s.description      = <<-DESC
Opens WhatsApp for macOS with a pre-filled message, or shares files through the
macOS share picker. Falls back to wa.me in the default browser when the desktop
app is not installed.
                       DESC
  s.homepage         = 'https://github.com/mrvijaysharma/whatsapp_share_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vijay Sharma' => 'mrvijaysharma@github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'whatsapp_share_plus/Sources/whatsapp_share_plus/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'whatsapp_share_plus_privacy' => ['whatsapp_share_plus/Sources/whatsapp_share_plus/PrivacyInfo.xcprivacy'],
  }
end
