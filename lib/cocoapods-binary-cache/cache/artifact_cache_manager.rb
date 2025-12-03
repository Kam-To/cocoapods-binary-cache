require "fileutils"
require "pathname"
require_relative "../helper/json"
require_relative "../../command/helper/zip"

module PodPrebuild
  # Manages binary artifact cache (local only)
  class ArtifactCacheManager
    attr_reader :config, :local_artifacts_dir, :local_current_dir

    def initialize(config)
      @config = config
      @local_artifacts_dir = Pathname(config.cache_path) + "artifacts"
      @local_current_dir = Pathname(config.prebuild_sandbox_path) + "current"
    end

    # Check if artifact exists locally
    def artifact_available?(artifact)
      local_available?(artifact)
    end

    # Fetch artifact from local cache
    # Returns: :local_hit or :miss
    def fetch_artifact(artifact)
      if local_available?(artifact)
        Pod::UI.puts "  - [Local Hit] #{artifact.artifact_id}".green
        link_to_current(artifact)
        return :local_hit
      end

      Pod::UI.puts "  - [Miss] #{artifact.artifact_id}".red
      :miss
    end

    # Publish artifact to local cache
    def publish_artifact(artifact, framework_path)
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      FileUtils.mkdir_p(artifact_dir)

      # 1. Copy framework/xcframework to artifact directory
      framework_basename = File.basename(framework_path)
      FileUtils.cp_r(framework_path, artifact_dir + framework_basename)

      # 2. Generate and save metadata
      metadata = artifact.generate_metadata
      metadata_file = artifact_dir + "metadata.json"
      File.write(metadata_file, JSON.pretty_generate(metadata))

      Pod::UI.puts "  - [Published] #{artifact.artifact_id}".green
    end

    # Link artifact to current directory for use
    def link_to_current(artifact)
      FileUtils.mkdir_p(@local_current_dir)

      # Get artifact directory
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      return unless artifact_dir.exist?

      # In artifact mode, we need to create a target directory structure
      # Expected: current/{target_name}/xxx.xcframework
      # Find all framework/xcframework files
      frameworks = Dir.glob(artifact_dir + "*.{framework,xcframework}")

      frameworks.each do |framework_path|
        framework_name = File.basename(framework_path)
        # Use pod name as target name (remove .xcframework/.framework extension)
        target_name = framework_name.sub(/\.(xc)?framework$/, '')

        # Create target directory: current/{target_name}/
        target_dir = @local_current_dir + target_name
        FileUtils.mkdir_p(target_dir)

        # Link framework to current/{target_name}/xxx.xcframework
        link_path = target_dir + framework_name

        # Remove existing link/directory
        FileUtils.rm_rf(link_path) if link_path.exist?

        # Create symlink
        FileUtils.ln_s(framework_path, link_path)

        # Create .pod_name flag file so prebuild_sandbox can identify the pod
        # Use artifact name (pod name) from the artifact object
        pod_name_file = target_dir + "#{artifact.name}.pod_name"
        File.write(pod_name_file, "")

        # Copy metadata.json to target directory for resource handling
        metadata_src = artifact_dir + "metadata.json"
        metadata_dst = target_dir + "metadata.json"
        if metadata_src.exist?
          FileUtils.cp(metadata_src, metadata_dst)
        end
      end
    end

    # Clean up old artifacts based on retention policy
    def cleanup_old_artifacts(retention_policy = {})
      return unless @local_artifacts_dir.exist?

      strategy = retention_policy[:strategy] || :lru
      max_count = retention_policy[:max_count]
      max_size_mb = retention_policy[:max_size_mb]

      case strategy
      when :lru
        cleanup_by_lru(max_count, max_size_mb)
      else
        Pod::UI.warn "Unknown cleanup strategy: #{strategy}"
      end
    end

    private

    # Check if artifact exists locally
    def local_available?(artifact)
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      artifact_dir.exist? && artifact_dir.directory?
    end

    # Cleanup artifacts using LRU strategy
    def cleanup_by_lru(max_count, max_size_mb)
      return unless @local_artifacts_dir.exist?

      artifacts = Dir.glob(@local_artifacts_dir + "*").map { |path| Pathname(path) }
      return if artifacts.empty?

      # Sort by access time (LRU)
      artifacts.sort_by!(&:atime)

      # Remove oldest artifacts if exceeding max_count
      if max_count && artifacts.size > max_count
        to_remove = artifacts[0...(artifacts.size - max_count)]
        to_remove.each do |path|
          Pod::UI.puts "  - [Cleanup] Removing old artifact: #{path.basename}"
          FileUtils.rm_rf(path)
        end
        artifacts = artifacts[(artifacts.size - max_count)..-1]
      end

      # Remove oldest artifacts if exceeding max_size_mb
      if max_size_mb
        total_size_mb = artifacts.sum { |path| dir_size_mb(path) }
        while total_size_mb > max_size_mb && artifacts.any?
          path = artifacts.shift
          size_mb = dir_size_mb(path)
          Pod::UI.puts "  - [Cleanup] Removing old artifact: #{path.basename} (#{size_mb.round(2)} MB)"
          FileUtils.rm_rf(path)
          total_size_mb -= size_mb
        end
      end
    end

    # Calculate directory size in MB
    def dir_size_mb(path)
      size_bytes = `du -sk #{path.shellescape}`.split.first.to_i * 1024
      size_bytes / (1024.0 * 1024.0)
    end
  end
end
