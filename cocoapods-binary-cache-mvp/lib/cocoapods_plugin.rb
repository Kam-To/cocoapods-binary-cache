# frozen_string_literal: true

# CocoaPods Binary Cache MVP - 插件入口
#
# 这个文件是 CocoaPods 加载插件的入口点
# 当用户在 Podfile 中写 `plugin 'cocoapods-binary-cache-mvp'` 时会自动加载

require_relative 'cocoapods-binary-cache-mvp/plugin'
require_relative 'cocoapods-binary-cache-mvp/commands/binary'
require_relative 'cocoapods-binary-cache-mvp/commands/prebuild'
