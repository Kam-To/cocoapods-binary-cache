require_relative "artifact_cache_manager"
require_relative "artifact_resolver"
require_relative "../helper/lockfile"

module PodPrebuild
  class CurrentArtifactPublisher
    attr_reader :prebuild_sandbox, :cache_manager, :artifacts_by_name

    def initialize(config:, prebuild_sandbox:, artifacts_by_name: {}, lockfile: nil, sandbox: nil, build_settings_provider: nil)
      @prebuild_sandbox = prebuild_sandbox
      @cache_manager = ArtifactCacheManager.new(config)
      @artifacts_by_name = artifacts_by_name || {}
      @resolver = if lockfile && sandbox
                    ArtifactResolver.new(PodPrebuild::Lockfile.new(lockfile), sandbox, build_settings_provider)
                  end
    end

    def publish
      current_dir = prebuild_sandbox.generate_framework_path
      return 0 unless current_dir.exist?

      processed = 0

      prebuild_sandbox.exsited_framework_pod_names.each do |pod_name|
        target_names = prebuild_sandbox.existed_target_names_for_pod_name(pod_name)
        next if target_names.empty?

        if target_names.count > 1
          raise Informative, "Multiple prebuild targets for #{pod_name} are not supported: #{target_names}"
        end

        artifact = resolve_artifact(pod_name)
        unless artifact
          Pod::UI.warn "Failed to resolve artifact for #{pod_name}"
          next
        end

        target_dir = prebuild_sandbox.framework_folder_path_for_target_name(target_names.first)
        framework_path = Dir.glob(target_dir + "*.{framework,xcframework}").first
        unless framework_path
          Pod::UI.warn "Framework file not found for #{pod_name} in #{target_dir}"
          next
        end

        Pod::UI.puts "Publishing artifact: #{pod_name}".green
        cache_manager.publish_artifact(artifact, framework_path)
        processed += 1
      end

      processed
    end

    private

    def resolve_artifact(pod_name)
      artifacts_by_name[pod_name] || @resolver&.resolve_artifact(pod_name)
    end
  end
end
