Pod::Spec.new do |s|
  s.name             = 'native_macos'
  s.version          = '0.2.0'
  s.summary          = 'Real AppKit controls and Liquid Glass for Flutter on macOS.'
  s.description      = <<-DESC
Embeds native AppKit views (NSGlassEffectView, NSButton, NSSwitch, NSSlider and
more) in Flutter macOS apps.
                       DESC
  s.homepage         = 'https://github.com/Seungpyo1007/native_macos'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Seungpyo' => 'rush94434@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files = 'native_macos/Sources/native_macos/**/*.swift'
  s.resource_bundles = {'native_macos_privacy' => ['native_macos/Sources/native_macos/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
