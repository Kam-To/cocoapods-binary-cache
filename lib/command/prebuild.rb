# ========================================
# 文件说明: Prebuild 命令实现
# ========================================
# 这个命令负责预编译标记为 :binary => true 的 pods
#
# 使用方式:
#   pod binary prebuild [CACHE-BRANCH]
#
# 参数说明:
#   CACHE-BRANCH: 可选，指定缓存分支，默认为 "master"
#
# 所有编译行为配置都在 Podfile 中定义，包括:
#   - prebuild_config: 编译配置（Debug/Release）
#   - prebuild_all_pods: 是否强制重新编译所有 pods
#   - 等等...
# ========================================

require_relative "executor/prebuilder"
require_relative "../cocoapods-binary-cache/pod-binary/prebuild_dsl"

module Pod
  class Command
    class Binary < Command
      class Prebuild < Binary
        attr_reader :prebuilder

        # 定义位置参数：缓存分支（可选）
        self.arguments = [CLAide::Argument.new("CACHE-BRANCH", false)]

        # 定义命令行选项
        # 这些是运行时标志，不是配置项
        def self.options
          [
            ["--repo-update", "Update pod repo before installing"],
            ["--no-fetch", "Do not perform a cache fetch beforehand"],
            ["--push", "Push cache to repo upon completion"]
          ]
        end

        # 初始化方法
        # @param argv [CLAide::ARGV] 命令行参数解析对象
        #
        # 执行流程：
        # 1. 调用父类初始化（加载 Podfile）
        # 2. 设置内部状态标志（告诉系统处于 prebuild 模式）
        # 3. 创建 prebuilder 执行器
        def initialize(argv)
          super

          # 设置内部状态：标记当前为 prebuild 任务
          # 这个标志会影响 CocoaPods hooks 的行为
          prebuild_config.dsl_config[:prebuild_job] = true

          # 创建 prebuilder 执行器
          @prebuilder = PodPrebuild::CachePrebuilder.new(
            config: prebuild_config,
            cache_branch: argv.shift_argument || "master",  # 获取缓存分支参数
            repo_update: argv.flag?("repo-update"),         # 是否更新 pod repo
            no_fetch: argv.flag?("fetch") == false,         # 是否跳过 fetch
            push_cache: argv.flag?("push")                  # 是否在完成后 push
          )
        end

        # 执行 prebuild 命令
        # 实际工作委托给 prebuilder 执行器
        def run
          @prebuilder.run
        end
      end
    end
  end
end
