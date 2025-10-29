Pod::Spec.new do |s|
  s.name             = 'cactus'
  s.version          = '0.0.3'
  s.summary          = 'AI Framework to run AI on-device'
  s.description      = <<-DESC
A Flutter plugin for Cactus Utilities, providing access to native Cactus functionalities.
                       DESC
  s.homepage         = 'http://cactuscompute.com' 
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Cactus Compute' => 'founders@cactuscompute.com' } 

  s.source           = { :path => '.' }

  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.swift_version = '5.0'
  s.vendored_frameworks = 'cactus.xcframework'
  s.frameworks = 'Accelerate', 'Foundation', 'Metal', 'MetalKit'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_ENABLE_MODULES' => 'YES', 
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }

  s.user_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'CLANG_CXX_LIBRARY' => 'libc++' 
  }

end
