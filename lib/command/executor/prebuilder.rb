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
require_relative "../../cocoapods-binary-cache/cache/current_artifact_publisher"
require_relative "../../cocoapods-binary-cache/helper/resolved_lockfile"

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
    # 流程：prebuild → publish_artifacts
    def run
      prebuild        # 执行预编译
      publish_artifacts  # 发布新编译的 artifacts 到本地缓存
      cleanup_prebuild_sandbox
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

    # 发布 artifacts 到缓存
    # 只发布 _Prebuild/current/ 中存在的 pods（即本次编译的 pods）
    #
    # 工作原理：
    # - Cache hit 的 pods 不会出现在 current/ 中
    # - 只有 cache miss 的 pods 才会被重新编译并放入 current/
    # - 因此遍历 current/ 目录即可实现增量发布
    def publish_artifacts
      Pod::UI.step("Publishing artifacts") do
        lockfile = project_lockfile || installer.lockfile
        return unless lockfile

        publisher = PodPrebuild::CurrentArtifactPublisher.new(
          config: @config,
          prebuild_sandbox: Pod::PrebuildSandbox.from_standard_sandbox(installer.sandbox),
          artifacts_by_name: PodPrebuild.state.artifacts,
          lockfile: PodPrebuild::ResolvedLockfile.from_specs(installer.analysis_result.specifications, lockfile),
          sandbox: installer.sandbox,
          build_settings_provider: @config.validate_prebuilt_settings
        )

        published_count = publisher.publish

        Pod::UI.puts "Published #{published_count} artifact(s)".green

      end
    end

    def project_lockfile
      lockfile_path = Pathname(Pod::Config.instance.lockfile_path || "Podfile.lock")
      return unless lockfile_path.exist?

      Pod::Lockfile.from_file(lockfile_path)
    rescue => e
      Pod::UI.warn "Failed to load project Podfile.lock: #{e.message}"
      nil
    end

    def cleanup_prebuild_sandbox
      prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(installer.sandbox)
      return unless prebuild_sandbox.root.exist?

      FileUtils.rm_rf(prebuild_sandbox.root)
      Pod::UI.puts "Removed temporary prebuild sandbox: #{prebuild_sandbox.root}".yellow
    end
  end
end
