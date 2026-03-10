require_relative "validation_result"
require_relative "artifact_resolver"
require_relative "artifact_cache_manager"

module PodPrebuild
  # 使用基于 artifact 的版本控制验证缓存
  class ArtifactsCacheValidator
    attr_reader :pod_lockfile, :sandbox, :validate_prebuilt_settings, :ignored_pods, :prebuilt_pod_names
    attr_reader :resolved_artifacts

    def initialize(options)
      @pod_lockfile = options[:pod_lockfile] && PodPrebuild::Lockfile.new(options[:pod_lockfile])
      @sandbox = options[:sandbox]
      @validate_prebuilt_settings = options[:validate_prebuilt_settings]
      @ignored_pods = options[:ignored_pods] || Set.new
      @prebuilt_pod_names = options[:prebuilt_pod_names] || Set.new
      @config = PodPrebuild.config
      @resolved_artifacts = {}
    end

    # 使用 artifact 版本控制验证缓存
    # 返回：CacheValidationResult
    def validate(*)
      return CacheValidationResult.new if @pod_lockfile.nil?

      # 过滤要验证的 pods（仅预构建的、未忽略的 pods）
      pods_to_validate = filter_pods_to_validate

      # 为所有 pods 解析 artifacts
      resolver = ArtifactResolver.new(
        @pod_lockfile,
        @sandbox,
        @validate_prebuilt_settings
      )
      artifacts = resolver.resolve_artifacts(pods_to_validate)
      @resolved_artifacts = artifacts.each_with_object({}) { |artifact, map| map[artifact.name] = artifact }

      # 检查 artifact 可用性
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

    # 过滤应该被验证的 pods
    # 仅包括：未被忽略的预构建 pods
    def filter_pods_to_validate
      all_pods = @pod_lockfile.pods.keys

      # 过滤掉被忽略的 pods
      pods = all_pods.reject { |name| @ignored_pods.include?(name.split('/').first) }

      # 仅过滤预构建的 pods
      pods = pods.select { |name| @prebuilt_pod_names.include?(name.split('/').first) }

      # 仅验证根 specs（不包括 subspecs）
      pods.reject { |name| name.include?('/') }
    end
  end
end
