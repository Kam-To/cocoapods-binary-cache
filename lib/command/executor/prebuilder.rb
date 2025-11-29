require_relative "base"
require_relative "fetcher"
require_relative "pusher"

module PodPrebuild
  class CachePrebuilder < CommandExecutor
    attr_reader :repo_update, :fetcher, :pusher

    def initialize(options)
      super(options)
      @repo_update = options[:repo_update]
      @fetcher = PodPrebuild::CacheFetcher.new(options) unless options[:no_fetch]
      @pusher = PodPrebuild::CachePusher.new(options) if options[:push_cache]
    end

    def run
      @fetcher&.run
      prebuild
      changes = PodPrebuild::JSONFile.new(@config.prebuild_delta_path)
      return if changes.empty?

      sync_cache(changes)
      @pusher&.run
    end

    private

    def prebuild
      Pod::UI.step("Installation") do
        installer.repo_update = @repo_update
        installer.install!
      end
    end

    def sync_cache(changes)
      sync_cache_with_artifacts(changes)
    end

    def sync_cache_with_artifacts(changes)
      Pod::UI.step("Syncing artifacts cache") do
        # IMPORTANT: Use installer's lockfile, not Pod::Config.instance.lockfile
        # The installer's lockfile is updated during the installation process
        lockfile = installer.lockfile
        return unless lockfile

        resolver = PodPrebuild::ArtifactResolver.new(
          PodPrebuild::Lockfile.new(lockfile),
          installer.sandbox,
          @config.validate_prebuilt_settings
        )

        cache_manager = PodPrebuild::ArtifactCacheManager.new(@config)

        changes["updated"].each do |pod_name|
          Pod::UI.puts "Publishing artifact for: #{pod_name}".green

          # Resolve artifact for this pod
          artifact = resolver.resolve_artifact(pod_name)
          unless artifact
            Pod::UI.warn "Failed to resolve artifact for #{pod_name}"
            next
          end

          # In artifact mode, frameworks are in _Prebuild/current/PodName/
          # Structure: _Prebuild/current/PodName/PodName.xcframework
          framework_dir = Pathname(@config.prebuild_sandbox_path) + "current" + pod_name

          Pod::UI.puts "  Looking for framework in: #{framework_dir}".blue if @config.strict_diagnosis?

          unless framework_dir.exist?
            Pod::UI.warn "Framework directory not found for #{pod_name} at #{framework_dir}"
            Pod::UI.warn "Available directories in _Prebuild/current: #{(Pathname(@config.prebuild_sandbox_path) + 'current').children.map(&:basename).join(', ')}" rescue nil
            next
          end

          # Find actual framework/xcframework file in the pod directory
          framework_file = Dir.glob(framework_dir + "*.{framework,xcframework}").first

          unless framework_file
            Pod::UI.warn "Framework file not found for #{pod_name} in #{framework_dir}"
            Pod::UI.warn "Directory contents: #{Dir.glob(framework_dir + '*').map { |f| File.basename(f) }.join(', ')}"
            next
          end

          Pod::UI.puts "  Found framework: #{framework_file}".blue if @config.strict_diagnosis?

          # Publish artifact
          begin
            cache_manager.publish_artifact(artifact, framework_file)
          rescue => e
            Pod::UI.warn "Failed to publish artifact for #{pod_name}: #{e.message}"
            Pod::UI.warn e.backtrace.join("\n") if @config.strict_diagnosis?
          end
        end

        # Clean up old artifacts based on retention policy
        cache_manager.cleanup_old_artifacts(@config.local_artifact_retention)
      end
    end

  end
end
