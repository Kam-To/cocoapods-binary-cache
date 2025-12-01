# frozen_string_literal: true

# 加载所有核心模块
require_relative 'config/config'
require_relative 'cache/artifact'
require_relative 'cache/manager'
require_relative 'cache/validator'
require_relative 'builder/framework_builder'
require_relative 'hooks/pre_install'

module CocoapodsBinaryCacheMVP
  # 插件版本号
  VERSION = '0.1.0'

  # 全局配置访问器
  def self.config
    Config.instance
  end

  # 插件主模块
  # 负责注册 CocoaPods 钩子和命令
  class Plugin
    # 注册插件
    def self.register
      # 注册 DSL 方法到 Podfile
      register_dsl

      # 注册钩子
      register_hooks
    end

    # 注册 DSL 方法
    # 让用户可以在 Podfile 中使用 config_binary_cache 方法
    def self.register_dsl
      Pod::Podfile::DSL.class_eval do
        # 配置二进制缓存
        #
        # @param options [Hash] 配置选项
        # @example
        #   config_binary_cache(
        #     cache_repo: { "default" => { "local" => "~/.cache" } },
        #     prebuild_config: "Release"
        #   )
        def config_binary_cache(options)
          CocoapodsBinaryCacheMVP.config.update(options)
        end
      end
    end

    # 注册 CocoaPods 钩子
    def self.register_hooks
      Pod::HooksManager.register('cocoapods-binary-cache-mvp', :pre_install) do |context|
        PreInstallHook.new(context).run
      end
    end
  end
end

# 自动注册插件
CocoapodsBinaryCacheMVP::Plugin.register
