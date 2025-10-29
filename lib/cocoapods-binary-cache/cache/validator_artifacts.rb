require_relative "validation_result"
require_relative "artifact_resolver"
require_relative "artifact_cache_manager"

module PodPrebuild
  # Validates cache using artifact-based versioning
  class ArtifactsCacheValidator
    attr_reader :pod_lockfile, :sandbox, :validate_prebuilt_settings, :ignored_pods, :prebuilt_pod_names

    def initialize(options)
      @pod_lockfile = options[:pod_lockfile] && PodPrebuild::Lockfile.new(options[:pod_lockfile])
      @sandbox = options[:sandbox]
      @validate_prebuilt_settings = options[:validate_prebuilt_settings]
      @ignored_pods = options[:ignored_pods] || Set.new
      @prebuilt_pod_names = options[:prebuilt_pod_names] || Set.new
      @config = PodPrebuild.config
    end

    # Validate cache using artifact versioning
    # Returns: CacheValidationResult
    def validate(*)
      return CacheValidationResult.new if @pod_lockfile.nil?

      # Filter pods to validate (only prebuilt, non-ignored pods)
      pods_to_validate = filter_pods_to_validate

      # Resolve artifacts for all pods
      resolver = ArtifactResolver.new(
        @pod_lockfile,
        @sandbox,
        @validate_prebuilt_settings
      )
      artifacts = resolver.resolve_artifacts(pods_to_validate)

      # Check artifact availability
      cache_manager = ArtifactCacheManager.new(@config)

      hit = Set.new
      missed = {}

      artifacts.each do |artifact|
        result = cache_manager.fetch_artifact(artifact)

        case result
        when :local_hit, :remote_hit
          hit << artifact.name
        when :miss
          missed[artifact.name] = "Artifact not available: #{artifact.artifact_id}"
        end
      end

      CacheValidationResult.new(missed, hit)
    end

    private

    # Filter pods that should be validated
    # Only include: prebuilt pods that are not ignored
    def filter_pods_to_validate
      all_pods = @pod_lockfile.pods.keys

      # Filter out ignored pods
      pods = all_pods.reject { |name| @ignored_pods.include?(name.split('/').first) }

      # Filter to only prebuilt pods
      pods = pods.select { |name| @prebuilt_pod_names.include?(name.split('/').first) }

      # Only validate root specs (not subspecs)
      pods.reject { |name| name.include?('/') }
    end
  end
end
