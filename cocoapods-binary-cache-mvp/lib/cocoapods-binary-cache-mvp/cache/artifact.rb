# frozen_string_literal: true

require 'digest'

module CocoapodsBinaryCacheMVP
  # Artifact 数据结构
  #
  # Artifact 代表一个预编译的框架，包含：
  # - Pod 名称
  # - 版本信息
  # - 唯一的 Artifact ID（基于内容哈希）
  class Artifact
    # Pod 名称
    # @return [String]
    attr_reader :name

    # Pod 版本
    # @return [String]
    attr_reader :version

    # Artifact ID（哈希值）
    # @return [String]
    attr_reader :artifact_id

    # 哈希因子数据
    # @return [Hash]
    attr_reader :hash_data

    # 初始化 Artifact
    #
    # @param name [String] Pod 名称
    # @param version [String] Pod 版本
    # @param hash_data [Hash] 用于计算哈希的数据
    def initialize(name:, version:, hash_data:)
      @name = name
      @version = version
      @hash_data = hash_data
      @artifact_id = calculate_artifact_id
    end

    # 计算 Artifact ID
    #
    # 基于配置的哈希因子计算唯一标识符
    # @return [String] 格式: "PodName-hash"
    def calculate_artifact_id
      # 获取配置的哈希因子
      factors = CocoapodsBinaryCacheMVP.config.artifact_hash_factors

      # 收集哈希数据
      hash_components = factors.map do |factor|
        @hash_data[factor]
      end.compact

      # 计算 SHA256 哈希
      hash_string = hash_components.join('-')
      hash_value = Digest::SHA256.hexdigest(hash_string)[0..15]  # 取前16位

      "#{@name}-#{hash_value}"
    end

    # Artifact 缓存路径
    #
    # @return [String] Artifact 在缓存中的路径
    def cache_path
      config = CocoapodsBinaryCacheMVP.config
      return nil unless config.artifacts_path

      File.join(config.artifacts_path, @artifact_id)
    end

    # 框架文件路径（在缓存中）
    #
    # @return [String] 框架压缩文件路径
    def framework_cache_path
      return nil unless cache_path

      ext = CocoapodsBinaryCacheMVP.config.xcframework ? 'xcframework' : 'framework'
      File.join(cache_path, "#{@name}.#{ext}.zip")
    end

    # 检查 Artifact 是否存在于缓存
    #
    # @return [Boolean] 是否存在
    def cached?
      framework_cache_path && File.exist?(framework_cache_path)
    end

    # Artifact 信息的哈希表示
    #
    # @return [Hash] Artifact 信息
    def to_h
      {
        name: @name,
        version: @version,
        artifact_id: @artifact_id,
        hash_data: @hash_data
      }
    end

    # Artifact 信息的字符串表示
    #
    # @return [String]
    def to_s
      "#{@name} (#{@version}) -> #{@artifact_id}"
    end
  end
end
