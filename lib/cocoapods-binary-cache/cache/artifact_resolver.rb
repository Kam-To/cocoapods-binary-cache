require_relative "artifact"
require_relative "artifact_version"

module PodPrebuild
  # Resolves all required binary artifacts from a lockfile
  class ArtifactResolver
    def initialize(lockfile, sandbox, build_settings_provider)
      @lockfile = lockfile
      @sandbox = sandbox
      @build_settings_provider = build_settings_provider
    end

    # Resolve all artifacts needed for the current pod installation
    # Returns: Array of Artifact objects
    def resolve_artifacts(pod_names = nil)
      pods_to_resolve = pod_names || @lockfile.pods.keys

      pods_to_resolve.map do |pod_name|
        # Skip if it's a subspec - we only create artifacts for root specs
        next if pod_name.include?('/')

        pod_version = @lockfile.pods[pod_name]
        next unless pod_version

        begin
          spec = load_pod_spec(pod_name, pod_version)
          build_settings = @build_settings_provider&.call(pod_name) || {}

          artifact_id = ArtifactVersion.generate(
            pod_name,
            pod_version,
            spec,
            build_settings
          )

          Artifact.new(
            name: pod_name,
            version: pod_version,
            artifact_id: artifact_id,
            spec: spec,
            build_settings: build_settings
          )
        rescue => e
          Pod::UI.warn "Failed to resolve artifact for #{pod_name}: #{e.message}"
          nil
        end
      end.compact
    end

    # Resolve a single artifact for a specific pod
    def resolve_artifact(pod_name)
      resolve_artifacts([pod_name]).first
    end

    private

    # Load pod specification from sandbox or spec repos
    def load_pod_spec(pod_name, pod_version)
      # Try to get spec from sandbox first (works during pod install)
      if @sandbox && @sandbox.respond_to?(:specification)
        begin
          spec = @sandbox.specification(pod_name)
          return spec if spec
        rescue => e
          # Sandbox spec not available, try alternative methods
        end
      end

      # Try to get from installed pods (analysis_result.specifications)
      if @sandbox && @sandbox.respond_to?(:root)
        podspec_path = @sandbox.root.parent + "Pods" + pod_name + "#{pod_name}.podspec.json"
        if podspec_path.exist?
          return Pod::Specification.from_file(podspec_path)
        end
      end

      # Fallback to searching in spec repos
      begin
        dependency = Pod::Dependency.new(pod_name, pod_version)
        set = Pod::Config.instance.sources_manager.search(dependency)

        if set && set.respond_to?(:specification)
          return set.specification
        end
      rescue => e
        Pod::UI.warn "Failed to search for #{pod_name} in spec repos: #{e.message}"
      end

      # Last resort: try to find any version in sources
      begin
        sources = Pod::Config.instance.sources_manager.all
        sources.each do |source|
          spec = source.specification(pod_name, pod_version) rescue nil
          return spec if spec
        end
      rescue => e
        Pod::UI.warn "Failed to load spec from sources: #{e.message}"
      end

      raise "Cannot load specification for #{pod_name} (#{pod_version})"
    end
  end
end
