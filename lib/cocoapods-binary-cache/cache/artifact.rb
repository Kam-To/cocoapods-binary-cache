module PodPrebuild
  # 表示特定 pod 版本及其构建配置的二进制 artifact
  class Artifact
    attr_reader :name, :version, :artifact_id, :spec, :build_settings

    def initialize(name:, version:, artifact_id:, spec:, build_settings:)
      @name = name
      @version = version
      @artifact_id = artifact_id
      @spec = spec
      @build_settings = build_settings
    end

    # artifact 的 Zip 文件名
    # 示例：AFNetworking-4.0.1-a1b2c3d4.zip
    def zip_name
      "#{artifact_id}.zip"
    end

    # artifact 的元数据文件名
    # 示例：AFNetworking-4.0.1-a1b2c3d4.json
    def metadata_name
      "#{artifact_id}.json"
    end

    # 从 artifact_id 提取的构建哈希
    # 示例：从 "AFNetworking-4.0.1-a1b2c3d4" 提取 "a1b2c3d4"
    def build_hash
      artifact_id.split('-').last
    end

    # 根 pod 名称（不包含 subspec）
    def root_name
      name.split('/').first
    end

    # 为此 artifact 生成元数据 JSON
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
