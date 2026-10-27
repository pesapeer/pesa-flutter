#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pesa_checkout.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pesa_checkout'
  s.version          = '0.1.0'
  s.summary          = 'Pesa card checkout: native card fields, 3-D Secure in the system browser.'
  s.description      = 'Native card fields that post straight to checkout.pesa.co; the screen is kept out of screenshots.'
  s.homepage         = 'https://pesa.co'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Pesa' => 'engineering@pesa.co' }
  s.source           = { :path => '.' }
  s.source_files = 'pesa_checkout/Sources/pesa_checkout/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'pesa_checkout_privacy' => ['pesa_checkout/Sources/pesa_checkout/PrivacyInfo.xcprivacy']}
end
