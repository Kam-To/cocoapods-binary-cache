module PodPrebuild
  # Represents a binary artifact for a specific pod version with build configuration
  class Artifact
    attr_reader :name, :version, :artifact_id, :spec, :build_settings

    def initialize(name:, version:, artifact_id:, spec:, build_settings:)
      @name = name
      @version = version
      @artifact_id = artifact_id
      @spec = spec
      @build_settings = build_settings
    end

    # Zip filename for the artifact
    # Example: AFNetworking-4.0.1-a1b2c3d4.zip
    def zip_name
      "#{artifact_id}.zip"
    end

    # Metadata filename for the artifact
    # Example: AFNetworking-4.0.1-a1b2c3d4.json
    def metadata_name
      "#{artifact_id}.json"
    end

    # Build hash extracted from artifact_id
    # Example: "a1b2c3d4" from "AFNetworking-4.0.1-a1b2c3d4"
    def build_hash
      artifact_id.split('-').last
    end

    # Root pod name (without subspec)
    def root_name
      name.split('/').first
    end

    # Generate metadata JSON for this artifact
    def generate_metadata
      {
        name: name,
        version: version,
        build_hash: build_hash,
        artifact_id: artifact_id,
        build_settings: normalize_build_settings,
        source: safe_attr(:source),
        frameworks: extract_frameworks,
        resources: safe_attr(:resources) || [],
        resource_bundles: safe_attr(:resource_bundles) || {},
        created_at: Time.now.utc.iso8601,
        created_by: ENV['USER'] || ENV['USERNAME'] || 'unknown',
        cocoapods_version: Pod::VERSION,
        xcode_version: xcode_version,
        swift_version: safe_attr(:swift_version)&.to_s
      }
    end

    private

    def safe_attr(attr_name)
      spec.respond_to?(attr_name) ? spec.public_send(attr_name) : nil
    rescue
      nil
    end

    def normalize_build_settings
      return {} if build_settings.nil?
      build_settings.is_a?(Hash) ? build_settings : {}
    end

    def extract_frameworks
      frameworks = []
      vendored = safe_attr(:vendored_frameworks)
      frameworks << "#{root_name}.framework" if vendored.nil? || vendored.empty?
      frameworks
    end

    def xcode_version
      version_output = `xcodebuild -version 2>/dev/null`.lines.first
      version_output ? version_output.strip : 'unknown'
    rescue
      'unknown'
    end
  end
end
