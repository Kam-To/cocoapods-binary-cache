# ========================================
# 文件说明: Prebuild 命令执行器
# ========================================
# 这个执行器负责协调预编译的完整流程：
# 1. Prebuild: 执行预编译
# 2. Publish: 发布新编译的 artifacts 到本地缓存
#
# 设计理念（分布式本地缓存）：
# - 不依赖 delta 文件跟踪变化
# - 直接发布 _Prebuild/current/ 中的所有 pods
# - 每个开发者维护独立的本地 artifact 缓存
# - 通过 artifact hash 确保唯一性和可复现性
# ========================================

require_relative "base"

module PodPrebuild
  class CachePrebuilder < CommandExecutor
    attr_reader :repo_update

    # 初始化预编译执行器
    # @param options [Hash] 配置选项
    #   - config: PodPrebuild::Config 配置对象
    #   - repo_update: 是否更新 pod repo
    def initialize(options)
      super(options)
      @repo_update = options[:repo_update]
    end

    # 执行预编译流程
    # 流程：prebuild
    def run
      prebuild        # 执行预编译
    end

    private

    # 执行预编译
    # 调用 CocoaPods 的安装流程
    def prebuild
      Pod::UI.step("Installation") do
        installer.repo_update = @repo_update
        installer.install!
      end
    end
  end
end
