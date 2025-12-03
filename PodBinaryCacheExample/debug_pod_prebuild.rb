# 强制使用当前示例工程的 Gemfile 并切换到该目录
ENV['BUNDLE_GEMFILE'] = File.expand_path('Gemfile', __dir__)
Dir.chdir(__dir__)

# 设置 UTF-8 以避免 unicode_normalize 在 ASCII-8BIT 上的异常
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
ENV['LANG'] ||= 'en_US.UTF-8'
ENV['LC_ALL'] ||= 'en_US.UTF-8'

# 引导 Bundler 使用 PodBinaryCacheExample/Gemfile 中的本地 CocoaPods 与插件
require "bundler/setup"

# 允许通过环境变量传入额外的 CLI 参数，例如：
#   PREBUILD_ARGS="--push --repo-update --config=Release" ruby debug_pod_prebuild.rb
extra_args = ENV["PREBUILD_ARGS"]&.split(/\s+/) || []

# CocoaPods 本身和插件入口
require "cocoapods"
require "cocoapods-binary-cache/main"
require "command/binary"

# 打印当前使用的 CocoaPods 与插件版本，便于确认本地调试的是仓库代码
puts "Ruby:        #{RUBY_VERSION}"
puts "CocoaPods:   #{Pod::VERSION}" rescue nil
begin
  spec = Gem.loaded_specs["cocoapods-binary-cache"]
  puts "Plugin:      cocoapods-binary-cache #{spec.version} (#{spec.full_gem_path})"
rescue
  puts "Plugin:      cocoapods-binary-cache (path install)"
end

# 构造并运行命令：pod binary prebuild
argv = ["binary", "prebuild"] + extra_args
puts "Running: pod #{argv.join(" ")}"
begin
  Pod::Command.run(argv)
rescue => e
  warn "Error: #{e.class} - #{e.message}"
  warn e.backtrace.join("\n")
  raise
end