# frozen_string_literal: true

module CocoapodsBinaryCacheMVP
  # 缓存验证器
  #
  # 验证哪些 Pod 的缓存命中，哪些需要重新编译
  class CacheValidator
    # 验证结果
    # @return [Hash] { hit: Set<String>, missed: Set<String> }
    attr_reader :result

    # 初始化验证器
    #
    # @param lockfile [Pod::Lockfile] Podfile.lock
    # @param prebuilt_pods [Array<String>] 标记为预编译的 Pod 列表
    def initialize(lockfile, prebuilt_pods)
      @lockfile = lockfile
      @prebuilt_pods = Set.new(prebuilt_pods)
      @cache_manager = CacheManager.new
      @result = { hit: Set.new, missed: Set.new }
    end

    # 执行验证
    #
    # @return [Hash] 验证结果
    def validate
      @prebuilt_pods.each do |pod_name|
        if cache_hit?(pod_name)
          @result[:hit] << pod_name
        else
          @result[:missed] << pod_name
        end
      end

      print_summary
      @result
    end

    # 检查缓存是否命中
    #
    # @param pod_name [String] Pod 名称
    # @return [Boolean] 是否命中
    def cache_hit?(pod_name)
      artifact = create_artifact(pod_name)
      return false unless artifact

      @cache_manager.exists?(artifact)
    end

    # 创建 Artifact
    #
    # @param pod_name [String] Pod 名称
    # @return [Artifact, nil] Artifact 对象
    def create_artifact(pod_name)
      version = pod_version(pod_name)
      return nil unless version

      # 收集哈希数据
      hash_data = collect_hash_data(pod_name, version)

      Artifact.new(
        name: pod_name,
        version: version,
        hash_data: hash_data
      )
    end

    # 获取 Pod 版本
    #
    # @param pod_name [String] Pod 名称
    # @return [String, nil] 版本号
    def pod_version(pod_name)
      pod_hash = @lockfile.to_hash['PODS'].find do |pod|
        case pod
        when String
          pod.start_with?(pod_name)
        when Hash
          pod.keys.first.start_with?(pod_name)
        end
      end

      return nil unless pod_hash

      # 提取版本号
      pod_string = pod_hash.is_a?(Hash) ? pod_hash.keys.first : pod_hash
      match = pod_string.match(/\((.*?)\)/)
      match ? match[1] : nil
    end

    # 收集哈希数据
    #
    # @param pod_name [String] Pod 名称
    # @param version [String] 版本号
    # @return [Hash] 哈希数据
    def collect_hash_data(pod_name, version)
      config = CocoapodsBinaryCacheMVP.config

      data = {}

      # 源码哈希（使用版本号作为简化实现）
      data[:source] = version if config.artifact_hash_factors.include?(:source)

      # 依赖哈希
      if config.artifact_hash_factors.include?(:dependencies)
        data[:dependencies] = collect_dependencies(pod_name).sort.join(',')
      end

      # 构建设置哈希
      if config.artifact_hash_factors.include?(:build_settings)
        data[:build_settings] = config.prebuild_config  # Debug/Release
      end

      data
    end

    # 收集依赖
    #
    # @param pod_name [String] Pod 名称
    # @return [Array<String>] 依赖列表
    def collect_dependencies(pod_name)
      dependencies = []

      @lockfile.to_hash['PODS'].each do |pod|
        next unless pod.is_a?(Hash)

        pod_key = pod.keys.first
        next unless pod_key.start_with?(pod_name)

        # 获取依赖
        pod_deps = pod[pod_key] || []
        dependencies.concat(pod_deps.map { |dep| dep.split.first })
      end

      dependencies.uniq
    end

    # 打印验证摘要
    def print_summary
      Pod::UI.puts "\n缓存验证结果:".cyan
      Pod::UI.puts "  ✅ 命中: #{@result[:hit].count} 个".green
      @result[:hit].each { |name| Pod::UI.puts "    - #{name}".green }

      Pod::UI.puts "  ❌ 未命中: #{@result[:missed].count} 个".yellow
      @result[:missed].each { |name| Pod::UI.puts "    - #{name}".yellow }
    end
  end
end
