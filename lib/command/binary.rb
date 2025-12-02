# ========================================
# 文件说明: CocoaPods Binary 插件的基础命令类
# ========================================
# 这是所有 binary 子命令的父类，负责：
# 1. 定义通用的命令行选项（如 --repo）
# 2. 初始化配置和加载 Podfile
# 3. 为子命令提供共享的配置访问方法
#
# 子命令包括：
# - fetch: 拉取预编译缓存
# - prebuild: 预编译 binary pods
# - push: 推送预编译缓存
# - visualize: 可视化依赖关系
# ========================================

require "fileutils"
require_relative "config"
require_relative "fetch"
require_relative "prebuild"
require_relative "push"
require_relative "visualize"

module Pod
  class Command
    # Binary 命令的基类
    # 这是一个抽象命令，不能直接执行，只能通过子命令使用
    # 例如: pod binary fetch, pod binary prebuild
    class Binary < Command
      # 标记为抽象命令，意味着这个类只是基类，不能直接执行
      self.abstract_command = true

      # 定义所有 binary 子命令共享的命令行选项
      # 返回一个选项数组，每个选项是 [标志, 描述]
      def self.options
        [
          # --repo 选项：指定使用哪个缓存仓库
          # 对应 config_cocoapods_binary_cache 中 cache_repo 的 key
          ["--repo", "Cache repo (in accordance with `cache_repo` in `config_cocoapods_binary_cache`)"]
        ]
      end

      # 初始化方法
      # @param argv [CLAide::ARGV] 命令行参数解析对象
      #
      # 执行流程：
      # 1. 调用父类初始化
      # 2. 加载 Podfile（确保配置可用）
      # 3. 更新 CLI 配置（处理 --repo 等命令行参数）
      def initialize(argv)
        super  # 调用 CocoaPods 原生 Command 类的初始化
        load_podfile  # 加载项目的 Podfile
        update_cli_config(:repo => argv.option("repo"))  # 将 --repo 参数保存到配置中
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

      # 更新命令行配置
      # @param options [Hash] 要更新的配置项
      #
      # 将命令行参数（如 --repo）合并到配置的 cli_config 中
      # cli_config 的优先级高于 Podfile 中的 dsl_config
      #
      # 例如：
      #   命令: pod binary fetch --repo staging
      #   结果: config.cli_config[:repo] = "staging"
      def update_cli_config(options)
        PodPrebuild.config.cli_config.merge!(options)
      end
    end
  end
end
