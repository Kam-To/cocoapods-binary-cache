lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "cocoapods-binary-cache-mvp"
  spec.version       = "0.1.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]
  spec.summary       = "CocoaPods 二进制缓存插件（最小可行版本）"
  spec.description   = "通过预编译 Pod 框架并基于内容哈希缓存，显著减少项目构建时间"
  spec.homepage      = "https://github.com/your-org/cocoapods-binary-cache-mvp"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  # CocoaPods 依赖
  spec.add_dependency "cocoapods", ">= 1.5.0"

  # Zip 压缩支持
  spec.add_dependency "rubyzip", "~> 2.0"

  # 开发依赖
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
