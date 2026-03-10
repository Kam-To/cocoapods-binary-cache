require "fileutils"
require "pathname"
require_relative "../helper/json"
require_relative "../prebuild_output/metadata"
require_relative "../../command/helper/zip"

module PodPrebuild
  # 管理二进制 artifact 缓存（仅本地）
  class ArtifactCacheManager
    attr_reader :config, :local_artifacts_dir

    def initialize(config)
      @config = config
      @local_artifacts_dir = Pathname(config.cache_path) + "artifacts"
    end

    # 检查 artifact 是否在本地存在
    def artifact_available?(artifact)
      local_available?(artifact)
    end

    def artifact_dir_for(artifact)
      @local_artifacts_dir + artifact.artifact_id
    end

    def metadata_path_for(artifact)
      artifact_dir_for(artifact) + "metadata.json"
    end

    def metadata_for(artifact)
      PodPrebuild::Metadata.new(metadata_path_for(artifact))
    end

    def binary_paths_for(artifact)
      Dir.glob(artifact_dir_for(artifact) + "*.{framework,xcframework}").map { |path| Pathname(path) }
    end

    # 从本地缓存获取 artifact
    # 返回：:local_hit 或 :miss
    def fetch_artifact(artifact)
      if local_available?(artifact)
        Pod::UI.puts "  - [Local Hit] #{artifact.artifact_id}".green
        return :local_hit
      end

      Pod::UI.puts "  - [Miss] #{artifact.artifact_id}".red
      :miss
    end

    # 发布 artifact 到本地缓存
    def publish_artifact(artifact, framework_path)
      artifact_dir = artifact_dir_for(artifact)
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
      copy_support_files(framework_path, artifact_dir)

      # 2. 生成并保存元数据
      metadata = artifact.generate_metadata
      metadata_file = metadata_path_for(artifact)
      File.write(metadata_file, JSON.pretty_generate(metadata))
      validate_artifact!(artifact, artifact_dir, framework_basename)

      Pod::UI.puts "  - [Published] #{artifact.artifact_id}".green
    end

    private

    # 检查 artifact 是否在本地存在
    def local_available?(artifact)
      artifact_dir = artifact_dir_for(artifact)
      artifact_dir.exist? && artifact_dir.directory?
    end

    def copy_support_files(framework_path, artifact_dir)
      staging_dir = Pathname(framework_path).dirname
      staging_entries = staging_dir.children
      return unless staging_entries.any? { |entry| support_file_marker?(entry) }

      staging_entries.each do |entry|
        basename = entry.basename.to_s
        next if entry.to_s == framework_path.to_s
        next if basename == "metadata.json"
        next if basename.end_with?(".pod_name")

        destination = artifact_dir + basename
        FileUtils.rm_rf(destination) if destination.exist?
        FileUtils.cp_r(entry, destination)
      end
    end

    def support_file_marker?(entry)
      basename = entry.basename.to_s
      basename == "metadata.json" || basename.end_with?(".pod_name")
    end

    def framework_already_cached?(framework_path, artifact_dir)
      return false unless File.exist?(framework_path)

      source_realpath = File.realpath(framework_path)
      artifact_realpath = artifact_dir.realpath.to_s

      source_realpath == artifact_realpath || source_realpath.start_with?(artifact_realpath + File::SEPARATOR)
    rescue Errno::ENOENT
      false
    end

    def validate_artifact!(artifact, artifact_dir, framework_basename)
      missing = []
      missing << framework_basename unless (artifact_dir + framework_basename).exist?
      missing << "metadata.json" unless metadata_path_for(artifact).exist?
      raise "Incomplete artifact publish: missing #{missing.join(', ')}" if missing.any?
    end

  end
end
