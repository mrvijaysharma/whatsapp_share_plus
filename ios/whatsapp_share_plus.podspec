#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint whatsapp_share_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'whatsapp_share_plus'
  s.version          = '2.0.0'
  s.summary          = 'Share text, media, and documents to WhatsApp and WhatsApp Business.'
  s.description      = <<-DESC
Share text, images, video, audio, and documents to WhatsApp and WhatsApp Business.
Targets a contact by phone number, sends several files at once, installs sticker
packs, and builds wa.me links that work on every platform.
                       DESC
  s.homepage         = 'https://github.com/mrvijaysharma/whatsapp_share_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vijay Sharma' => 'mrvijaysharma@github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'whatsapp_share_plus/Sources/whatsapp_share_plus/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'whatsapp_share_plus_privacy' => ['whatsapp_share_plus/Sources/whatsapp_share_plus/PrivacyInfo.xcprivacy'],
  }
end
