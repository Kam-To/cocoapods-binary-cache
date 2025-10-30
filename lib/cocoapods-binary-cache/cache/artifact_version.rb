require "digest/sha2"
require "json"

module PodPrebuild
  class ArtifactVersion
    # Generate unique artifact identifier
    # Format: PodName-Version-BuildHash
    # Example: AFNetworking-4.0.1-a1b2c3d4
    def self.generate(pod_name, pod_version, spec, build_settings)
      build_hash = compute_build_hash(spec, build_settings)
      "#{pod_name}-#{pod_version}-#{build_hash}"
    end

    # Compute build hash based on all factors that affect binary output
    def self.compute_build_hash(spec, build_settings)
      content = collect_build_factors(spec, build_settings)
      Digest::SHA256.hexdigest(content.to_json)[0..7] # 8-char hash
    end

    # Collect all factors that influence the binary artifact
    def self.collect_build_factors(spec, build_settings)
      {
        # 0. Version - IMPORTANT: Include version to distinguish between different versions
        # Even if two versions have identical spec content, they should produce different artifacts
        version: safe_spec_attr(spec, :version).to_s,

        # 1. Source-related
        source: normalize_source(safe_spec_attr(spec, :source)),
        source_files: safe_spec_attr(spec, :source_files),
        public_header_files: safe_spec_attr(spec, :public_header_files),
        private_header_files: safe_spec_attr(spec, :private_header_files),
        vendored_frameworks: safe_spec_attr(spec, :vendored_frameworks),
        vendored_libraries: safe_spec_attr(spec, :vendored_libraries),

        # 2. Dependencies
        dependencies: safe_dependencies(spec),

        # 3. Build configuration
        compiler_flags: safe_spec_attr(spec, :compiler_flags),
        frameworks: normalize_array(safe_spec_attr(spec, :frameworks)),
        weak_frameworks: normalize_array(safe_spec_attr(spec, :weak_frameworks)),
        libraries: normalize_array(safe_spec_attr(spec, :libraries)),
        xcconfig: safe_spec_attr(spec, :xcconfig),
        pod_target_xcconfig: safe_spec_attr(spec, :pod_target_xcconfig),
        user_target_xcconfig: safe_spec_attr(spec, :user_target_xcconfig),
        build_settings: normalize_build_settings(build_settings),

        # 4. Platform and architecture
        platforms: safe_platforms(spec),
        deployment_target: extract_deployment_targets(spec),

        # 5. Other build-affecting factors
        requires_arc: safe_spec_attr(spec, :requires_arc),
        module_name: safe_spec_attr(spec, :module_name),
        module_map: safe_spec_attr(spec, :module_map),
        header_dir: safe_spec_attr(spec, :header_dir),
        header_mappings_dir: safe_spec_attr(spec, :header_mappings_dir),
        swift_version: safe_spec_attr(spec, :swift_version),

        # 6. Resource-related (may affect framework structure)
        resources: normalize_array(safe_spec_attr(spec, :resources)),
        resource_bundles: safe_spec_attr(spec, :resource_bundles),
        preserve_paths: normalize_array(safe_spec_attr(spec, :preserve_paths)),

        # 7. Scripting (may affect build)
        prepare_command: safe_spec_attr(spec, :prepare_command),
        script_phases: safe_spec_attr(spec, :script_phases)
      }
    end

    private_class_method :compute_build_hash, :collect_build_factors

    # Safe spec attribute access
    def self.safe_spec_attr(spec, attr_name)
      return nil unless spec.respond_to?(attr_name)
      spec.public_send(attr_name)
    rescue => e
      Pod::UI.warn "Failed to access spec attribute #{attr_name}: #{e.message}" if PodPrebuild.config.strict_diagnosis?
      nil
    end

    # Safe dependencies extraction
    def self.safe_dependencies(spec)
      return [] unless spec.respond_to?(:dependencies)
      spec.dependencies.map { |d| "#{d.name}:#{d.requirement}" }.sort
    rescue => e
      Pod::UI.warn "Failed to extract dependencies: #{e.message}" if PodPrebuild.config.strict_diagnosis?
      []
    end

    # Safe platforms extraction
    def self.safe_platforms(spec)
      return [] unless spec.respond_to?(:available_platforms)
      spec.available_platforms.map(&:name).sort
    rescue => e
      Pod::UI.warn "Failed to extract platforms: #{e.message}" if PodPrebuild.config.strict_diagnosis?
      []
    end

    # Normalize source to ensure consistent hashing
    def self.normalize_source(source)
      return {} if source.nil?

      source = source.dup
      # Remove volatile fields like :commit (use :tag instead if available)
      # Keep :git, :http, :tag, :branch
      source.delete(:commit) if source[:tag] || source[:branch]
      source
    end

    def self.normalize_array(value)
      return [] if value.nil?
      Array(value).sort
    end

    def self.normalize_build_settings(build_settings)
      return {} if build_settings.nil?

      # Extract callable result if it's a proc/lambda
      settings = build_settings.is_a?(Proc) ? {} : build_settings
      settings = settings.respond_to?(:call) ? {} : settings

      # Normalize to hash with sorted keys
      Hash[settings.sort]
    end

    def self.extract_deployment_targets(spec)
      targets = {}
      return targets unless spec.respond_to?(:available_platforms)

      spec.available_platforms.each do |platform|
        deployment_target = spec.deployment_target(platform.name) rescue nil
        targets[platform.name.to_s] = deployment_target.to_s if deployment_target
      end
      targets
    end

    private_class_method :normalize_source, :normalize_array, :normalize_build_settings, :extract_deployment_targets,
                         :safe_spec_attr, :safe_dependencies, :safe_platforms
  end
end
