require "fileutils"
require "pathname"
require_relative "../helper/json"
require_relative "../../command/helper/zip"

module PodPrebuild
  # 管理二进制 artifact 缓存（仅本地）
  class ArtifactCacheManager
    attr_reader :config, :local_artifacts_dir, :local_current_dir

    def initialize(config)
      @config = config
      @local_artifacts_dir = Pathname(config.cache_path) + "artifacts"
      @local_current_dir = Pathname(config.prebuild_sandbox_path) + "current"
    end

    # 检查 artifact 是否在本地存在
    def artifact_available?(artifact)
      local_available?(artifact)
    end

    # 从本地缓存获取 artifact
    # 返回：:local_hit 或 :miss
    def fetch_artifact(artifact)
      if local_available?(artifact)
        Pod::UI.puts "  - [Local Hit] #{artifact.artifact_id}".green
        link_to_current(artifact)
        return :local_hit
      end

      Pod::UI.puts "  - [Miss] #{artifact.artifact_id}".red
      :miss
    end

    # 发布 artifact 到本地缓存
    def publish_artifact(artifact, framework_path)
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      FileUtils.mkdir_p(artifact_dir)

      # Cache hit artifacts are linked into current/. Skip republishing when the
      # framework already resolves to this artifact directory.
      if framework_already_cached?(framework_path, artifact_dir)
        Pod::UI.puts "  - [Skip] #{artifact.artifact_id} already cached".yellow
        return
      end

      # 1. 将 framework/xcframework 复制到 artifact 目录
      framework_basename = File.basename(framework_path)
      FileUtils.cp_r(framework_path, artifact_dir + framework_basename)

      # 2. 生成并保存元数据
      metadata = artifact.generate_metadata
      metadata_file = artifact_dir + "metadata.json"
      File.write(metadata_file, JSON.pretty_generate(metadata))

      Pod::UI.puts "  - [Published] #{artifact.artifact_id}".green
    end

    # 将 artifact 链接到 current 目录以供使用
    def link_to_current(artifact)
      FileUtils.mkdir_p(@local_current_dir)

      # 获取 artifact 目录
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      return unless artifact_dir.exist?

      # 在 artifact 模式下，我们需要创建目标目录结构
      # 期望：current/{target_name}/xxx.xcframework
      # 查找所有 framework/xcframework 文件
      frameworks = Dir.glob(artifact_dir + "*.{framework,xcframework}")

      frameworks.each do |framework_path|
        framework_name = File.basename(framework_path)
        # 使用 pod 名称作为 target 名称（移除 .xcframework/.framework 扩展名）
        target_name = framework_name.sub(/\.(xc)?framework$/, '')

        # 创建 target 目录：current/{target_name}/
        target_dir = @local_current_dir + target_name
        FileUtils.mkdir_p(target_dir)

        # 将 framework 链接到 current/{target_name}/xxx.xcframework
        link_path = target_dir + framework_name

        # 移除现有的链接/目录
        FileUtils.rm_rf(link_path) if link_path.exist?

        # 创建符号链接
        FileUtils.ln_s(framework_path, link_path)

        # 创建 .pod_name 标志文件，以便 prebuild_sandbox 可以识别 pod
        # 使用 artifact 对象中的 artifact 名称（pod 名称）
        pod_name_file = target_dir + "#{artifact.name}.pod_name"
        File.write(pod_name_file, "")

        # 将 metadata.json 复制到 target 目录以处理资源
        metadata_src = artifact_dir + "metadata.json"
        metadata_dst = target_dir + "metadata.json"
        if metadata_src.exist?
          FileUtils.cp(metadata_src, metadata_dst)
        end
      end
    end

    private

    # 检查 artifact 是否在本地存在
    def local_available?(artifact)
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      artifact_dir.exist? && artifact_dir.directory?
    end

    def framework_already_cached?(framework_path, artifact_dir)
      return false unless File.exist?(framework_path)

      source_realpath = File.realpath(framework_path)
      artifact_realpath = artifact_dir.realpath.to_s

      source_realpath == artifact_realpath || source_realpath.start_with?(artifact_realpath + File::SEPARATOR)
    rescue Errno::ENOENT
      false
    end

  end
end
