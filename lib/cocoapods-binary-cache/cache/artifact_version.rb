require "digest/sha2"
require "json"

module PodPrebuild
  class ArtifactVersion
    # 生成唯一的 artifact 标识符
    # 格式：PodName-Version-BuildHash
    # 示例：AFNetworking-4.0.1-a1b2c3d4
    def self.generate(pod_name, pod_version, spec, build_settings, resolved_dependencies = [])
      build_hash = compute_build_hash(spec, build_settings, resolved_dependencies)
      "#{pod_name}-#{pod_version}-#{build_hash}"
    end

    # 基于所有影响二进制产物的因素计算构建哈希
    def self.compute_build_hash(spec, build_settings, resolved_dependencies)
      content = collect_build_factors(spec, build_settings, resolved_dependencies)
      Digest::SHA256.hexdigest(content.to_json)[0..7] # 8 字符哈希
    end

    # 收集所有影响二进制 artifact 的因素
    def self.collect_build_factors(spec, build_settings, resolved_dependencies)
      {
        # 0. 版本 - 重要：包含版本号以区分不同版本
        # 即使两个版本的 spec 内容相同，它们也应该产生不同的 artifacts
        version: safe_spec_attr(spec, :version).to_s,

        # 1. 源码相关
        source: normalize_source(safe_spec_attr(spec, :source)),
        source_files: safe_spec_attr(spec, :source_files),
        public_header_files: safe_spec_attr(spec, :public_header_files),
        private_header_files: safe_spec_attr(spec, :private_header_files),
        vendored_frameworks: safe_spec_attr(spec, :vendored_frameworks),
        vendored_libraries: safe_spec_attr(spec, :vendored_libraries),

        # 2. 依赖关系
        dependencies: safe_dependencies(spec),
        resolved_dependencies: normalize_array(resolved_dependencies),

        # 3. 构建配置
        compiler_flags: safe_spec_attr(spec, :compiler_flags),
        frameworks: normalize_array(safe_spec_attr(spec, :frameworks)),
        weak_frameworks: normalize_array(safe_spec_attr(spec, :weak_frameworks)),
        libraries: normalize_array(safe_spec_attr(spec, :libraries)),
        xcconfig: safe_spec_attr(spec, :xcconfig),
        pod_target_xcconfig: safe_spec_attr(spec, :pod_target_xcconfig),
        user_target_xcconfig: safe_spec_attr(spec, :user_target_xcconfig),
        build_settings: normalize_build_settings(build_settings),

        # 4. 平台和架构
        platforms: safe_platforms(spec),
        deployment_target: extract_deployment_targets(spec),

        # 5. 其他影响构建的因素
        requires_arc: safe_spec_attr(spec, :requires_arc),
        module_name: safe_spec_attr(spec, :module_name),
        module_map: safe_spec_attr(spec, :module_map),
        header_dir: safe_spec_attr(spec, :header_dir),
        header_mappings_dir: safe_spec_attr(spec, :header_mappings_dir),
        swift_version: safe_spec_attr(spec, :swift_version),

        # 6. 资源相关（可能影响 framework 结构）
        resources: normalize_array(safe_spec_attr(spec, :resources)),
        resource_bundles: safe_spec_attr(spec, :resource_bundles),
        preserve_paths: normalize_array(safe_spec_attr(spec, :preserve_paths)),

        # 7. 脚本（可能影响构建）
        prepare_command: safe_spec_attr(spec, :prepare_command),
        script_phases: safe_spec_attr(spec, :script_phases)
      }
    end

    private_class_method :compute_build_hash, :collect_build_factors

    # 安全地访问 spec 属性
    def self.safe_spec_attr(spec, attr_name)
      return nil unless spec.respond_to?(attr_name)
      spec.public_send(attr_name)
    rescue => e
      Pod::UI.warn "Failed to access spec attribute #{attr_name}: #{e.message}"
      nil
    end

    # 安全地提取依赖关系
    def self.safe_dependencies(spec)
      return [] unless spec.respond_to?(:dependencies)
      spec.dependencies.map { |d| "#{d.name}:#{d.requirement}" }.sort
    rescue => e
      Pod::UI.warn "Failed to extract dependencies: #{e.message}"
      []
    end

    # 安全地提取平台信息
    def self.safe_platforms(spec)
      return [] unless spec.respond_to?(:available_platforms)
      spec.available_platforms.map(&:name).sort
    rescue => e
      Pod::UI.warn "Failed to extract platforms: #{e.message}"
      []
    end

    # 规范化 source 以确保一致的哈希计算
    def self.normalize_source(source)
      return {} if source.nil?

      source = source.dup
      # 移除易变的字段如 :commit（如果有 :tag 或 :branch 则使用它们）
      # 保留 :git, :http, :tag, :branch
      source.delete(:commit) if source[:tag] || source[:branch]
      source
    end

    def self.normalize_array(value)
      return [] if value.nil?
      Array(value).sort
    end

    def self.normalize_build_settings(build_settings)
      return {} if build_settings.nil?

      # 如果是 proc/lambda，提取可调用结果
      settings = build_settings.is_a?(Proc) ? {} : build_settings
      settings = settings.respond_to?(:call) ? {} : settings

      # 规范化为带排序键的哈希表
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
