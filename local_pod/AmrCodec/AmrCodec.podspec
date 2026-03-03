#
#  Be sure to run `pod spec lint Development.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "AmrCodec"
  s.version      = "0.0.1"
  s.summary      = "A short description of AmrCodec."

  s.description  = <<-DESC
                    123123
                   DESC

  s.homepage     = "http://123/AmrCodec"

  s.license      = "MIT (123)"
  
  s.author             = { "沈晨豪" => "shenchenhao131@163.com" }
  

  s.source       = { :git => "http://123/AmrCodec.git", :tag => "#{s.version}" }


  s.source_files  = "AmrCodec/*.{h,m}", "AmrCodec/include/*/*.h"
  
  s.vendored_libraries = 'AmrCodec/lib/*.a'



end
