require "fileutils"
require "pathname"
require_relative "../helper/json"
require_relative "../../command/helper/zip"

module PodPrebuild
  # Manages binary artifact cache (local and remote)
  class ArtifactCacheManager
    attr_reader :config, :local_artifacts_dir, :local_current_dir, :remote_artifacts_dir

    def initialize(config)
      @config = config
      @local_artifacts_dir = Pathname(config.cache_path) + "artifacts"
      @local_current_dir = Pathname(config.prebuild_sandbox_path) + "current"
      @remote_artifacts_dir = config.local_cache? ? @local_artifacts_dir : Pathname(config.cache_path) + "artifacts"
    end

    # Check if artifact exists (local or remote)
    def artifact_available?(artifact)
      local_available?(artifact) || remote_available?(artifact)
    end

    # Fetch artifact (local first, then remote)
    # Returns: :local_hit, :remote_hit, or :miss
    def fetch_artifact(artifact)
      if local_available?(artifact)
        Pod::UI.puts "  - [Local Hit] #{artifact.artifact_id}".green
        link_to_current(artifact)
        return :local_hit
      end

      if remote_available?(artifact)
        Pod::UI.puts "  - [Remote Hit] #{artifact.artifact_id}".yellow
        download_artifact(artifact)
        link_to_current(artifact)
        return :remote_hit
      end

      Pod::UI.puts "  - [Miss] #{artifact.artifact_id}".red
      :miss
    end

    # Publish artifact to remote cache
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

      # 3. Zip artifact for remote storage (if using remote cache)
      unless config.local_cache?
        FileUtils.mkdir_p(@remote_artifacts_dir)
        zip_artifact(artifact_dir, @remote_artifacts_dir + artifact.zip_name)

        # 4. Copy metadata to remote
        FileUtils.cp(metadata_file, @remote_artifacts_dir + artifact.metadata_name)
      end

      Pod::UI.puts "  - [Published] #{artifact.artifact_id}".green
    end

    # Link artifact to current directory for use
    def link_to_current(artifact)
      FileUtils.mkdir_p(@local_current_dir)

      # Get artifact directory
      artifact_dir = @local_artifacts_dir + artifact.artifact_id
      return unless artifact_dir.exist?

      # In artifact mode, we link frameworks directly to current/
      # Find all framework/xcframework files
      frameworks = Dir.glob(artifact_dir + "*.{framework,xcframework}")

      frameworks.each do |framework_path|
        framework_name = File.basename(framework_path)
        link_path = @local_current_dir + framework_name

        # Remove existing link/directory
        FileUtils.rm_rf(link_path) if link_path.exist?

        # Create symlink
        FileUtils.ln_s(framework_path, link_path)
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

    # Check if artifact exists in remote cache
    def remote_available?(artifact)
      return false if config.local_cache?

      zip_path = @remote_artifacts_dir + artifact.zip_name
      zip_path.exist?
    end

    # Download artifact from remote cache
    def download_artifact(artifact)
      zip_path = @remote_artifacts_dir + artifact.zip_name
      artifact_dir = @local_artifacts_dir + artifact.artifact_id

      FileUtils.mkdir_p(artifact_dir)
      ZipUtils.unzip(zip_path.to_s, to_dir: artifact_dir.to_s)

      # Also download metadata if available
      metadata_path = @remote_artifacts_dir + artifact.metadata_name
      if metadata_path.exist?
        FileUtils.cp(metadata_path, artifact_dir + "metadata.json")
      end
    end

    # Zip artifact directory
    def zip_artifact(artifact_dir, output_zip_path)
      # Use system zip command
      Dir.chdir(artifact_dir.dirname) do
        basename = artifact_dir.basename
        cmd = "zip -r --symlinks #{output_zip_path.shellescape} #{basename.to_s.shellescape}"
        system(cmd)
      end
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
