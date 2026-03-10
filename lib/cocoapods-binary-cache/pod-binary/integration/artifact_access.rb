require_relative "../../cache/artifact_cache_manager"
require_relative "../../cache/artifact_reader"
require_relative "../../cache/artifact_resolver"
require_relative "../../helper/resolved_lockfile"

module Pod
  class Installer
    private

    def artifact_cache_manager
      @artifact_cache_manager ||= PodPrebuild::ArtifactCacheManager.new(PodPrebuild.config)
    end

    def artifact_resolver
      @artifact_resolver ||= PodPrebuild::ArtifactResolver.new(
        PodPrebuild::ResolvedLockfile.from_specs(analysis_result.specifications, lockfile),
        sandbox,
        PodPrebuild.config.validate_prebuilt_settings
      )
    end

    def artifact_reader_for(name)
      @artifact_readers ||= {}
      return @artifact_readers[name] if @artifact_readers.key?(name)

      artifact = PodPrebuild.state.artifact_for(name) || artifact_resolver.resolve_artifact(name)
      reader = artifact && PodPrebuild::ArtifactReader.new(artifact_cache_manager, artifact)
      @artifact_readers[name] = reader&.available? ? reader : nil
    end

    def targets_for_pod_name(name)
      @targets_for_pod_name ||= pod_targets.group_by(&:pod_name)
      @targets_for_pod_name[name] || []
    end
  end
end
