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
    # 流程：prebuild → publish_artifacts
    def run
      prebuild        # 执行预编译
      publish_artifacts  # 发布新编译的 artifacts 到本地缓存
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
        lockfile = installer.lockfile
        return unless lockfile

        resolver = PodPrebuild::ArtifactResolver.new(
          PodPrebuild::Lockfile.new(lockfile),
          installer.sandbox,
          @config.validate_prebuilt_settings
        )

        cache_manager = PodPrebuild::ArtifactCacheManager.new(@config)
        current_dir = Pathname(@config.prebuild_sandbox_path) + "current"

        # 检查 current 目录是否存在
        unless current_dir.exist?
          Pod::UI.puts "No artifacts to publish (current directory does not exist)".yellow
          return
        end

        # 遍历 current/ 中的所有 pod 目录
        published_count = 0
        current_dir.children.select(&:directory?).each do |pod_dir|
          pod_name = pod_dir.basename.to_s

          # 解析 artifact
          artifact = resolver.resolve_artifact(pod_name)
          unless artifact
            Pod::UI.warn "Failed to resolve artifact for #{pod_name}"
            next
          end

          # 查找 framework/xcframework 文件
          framework_file = Dir.glob(pod_dir + "*.{framework,xcframework}").first
          unless framework_file
            Pod::UI.warn "Framework file not found for #{pod_name} in #{pod_dir}"
            next
          end

          # 发布 artifact
          begin
            Pod::UI.puts "Publishing artifact: #{pod_name}".green
            cache_manager.publish_artifact(artifact, framework_file)
            published_count += 1
          rescue => e
            Pod::UI.warn "Failed to publish artifact for #{pod_name}: #{e.message}"
          end
        end

        Pod::UI.puts "Published #{published_count} artifact(s)".green

        # 清理旧的 artifacts（根据保留策略）
        cache_manager.cleanup_old_artifacts(@config.local_artifact_retention)
      end
    end
  end
end
