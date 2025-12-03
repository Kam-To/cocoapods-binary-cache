require_relative "artifact"
require_relative "artifact_version"

module PodPrebuild
  # 从 lockfile 解析所有需要的二进制 artifacts
  class ArtifactResolver
    def initialize(lockfile, sandbox, build_settings_provider)
      @lockfile = lockfile
      @sandbox = sandbox
      @build_settings_provider = build_settings_provider
    end

    # 解析当前 pod 安装所需的所有 artifacts
    # 返回：Artifact 对象数组
    def resolve_artifacts(pod_names = nil)
      pods_to_resolve = pod_names || @lockfile.pods.keys

      pods_to_resolve.map do |pod_name|
        # 跳过 subspec - 我们只为根 spec 创建 artifacts
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

    # 解析特定 pod 的单个 artifact
    def resolve_artifact(pod_name)
      resolve_artifacts([pod_name]).first
    end

    private

    # 从 sandbox 或 spec repos 加载 pod 规格
    def load_pod_spec(pod_name, pod_version)
      # 首先尝试从 sandbox 获取 spec（在 pod install 期间有效）
      if @sandbox && @sandbox.respond_to?(:specification)
        begin
          spec = @sandbox.specification(pod_name)
          return spec if spec
        rescue => e
          # Sandbox spec 不可用，尝试替代方法
        end
      end

      # 尝试从已安装的 pods 获取（analysis_result.specifications）
      if @sandbox && @sandbox.respond_to?(:root)
        podspec_path = @sandbox.root.parent + "Pods" + pod_name + "#{pod_name}.podspec.json"
        if podspec_path.exist?
          return Pod::Specification.from_file(podspec_path)
        end
      end

      # 回退到在 spec repos 中搜索
      begin
        dependency = Pod::Dependency.new(pod_name, pod_version)
        set = Pod::Config.instance.sources_manager.search(dependency)

        if set && set.respond_to?(:specification)
          return set.specification
        end
      rescue => e
        Pod::UI.warn "Failed to search for #{pod_name} in spec repos: #{e.message}"
      end

      # 最后的手段：尝试在 sources 中找到任何版本
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
