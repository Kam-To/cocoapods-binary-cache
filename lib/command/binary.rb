# ========================================
# 文件说明: CocoaPods Binary 插件的基础命令类
# ========================================
# 这是所有 binary 子命令的父类，负责：
# 1. 初始化配置和加载 Podfile
# 2. 为子命令提供共享的配置访问方法
#
# 设计理念：
# - 所有配置都在 Podfile 中通过 config_cocoapods_binary_cache 定义
# - 不支持命令行参数覆盖配置（保持配置的一致性和可追溯性）
#
# 子命令包括：
# - fetch: 拉取预编译缓存
# - prebuild: 预编译 binary pods
# - push: 推送预编译缓存
# ========================================

require "fileutils"
require_relative "config"
require_relative "fetch"
require_relative "prebuild"
require_relative "push"

module Pod
  class Command
    # Binary 命令的基类
    # 这是一个抽象命令，不能直接执行，只能通过子命令使用
    # 例如: pod binary fetch, pod binary prebuild
    class Binary < Command
      # 标记为抽象命令，意味着这个类只是基类，不能直接执行
      self.abstract_command = true

      # 初始化方法
      # @param argv [CLAide::ARGV] 命令行参数解析对象
      #
      # 执行流程：
      # 1. 调用父类初始化
      # 2. 加载 Podfile（确保配置可用）
      def initialize(argv)
        super  # 调用 CocoaPods 原生 Command 类的初始化
        load_podfile  # 加载项目的 Podfile
      end

      # 获取预编译配置对象
      # @return [PodPrebuild::Config] 全局配置单例
      #
      # 这个配置对象包含了所有插件相关的配置：
      # - cache_repo: 缓存仓库地址
      # - prebuild_config: 编译配置（Debug/Release）
      # - excluded_pods: 排除的 pods
      # 等等...
      def prebuild_config
        @prebuild_config ||= PodPrebuild.config
      end

      # 加载 Podfile
      # @return [Pod::Podfile] Podfile 对象
      #
      # 通过 CocoaPods 的全局配置实例获取 Podfile
      # Podfile 包含了项目的所有依赖声明和配置
      def load_podfile
        Pod::Config.instance.podfile
      end
    end
  end
end
