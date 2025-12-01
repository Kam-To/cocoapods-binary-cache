# frozen_string_literal: true

require 'singleton'

module CocoapodsBinaryCacheMVP
  # 全局配置管理器
  #
  # 使用单例模式，确保全局只有一个配置实例
  # 负责管理所有插件配置，包括缓存路径、构建选项等
  class Config
    include Singleton

    # 缓存仓库配置
    # @return [Hash] 缓存仓库信息
    attr_reader :cache_repo

    # 预编译配置（Debug/Release）
    # @return [String]
    attr_reader :prebuild_config

    # 预编译沙盒路径
    # @return [String]
    attr_reader :prebuild_sandbox_path

    # 是否启用 xcframework
    # @return [Boolean]
    attr_reader :xcframework

    # Artifact 哈希因子
    # @return [Array<Symbol>]
    attr_reader :artifact_hash_factors

    # 是否是预编译任务
    # @return [Boolean]
    attr_accessor :prebuild_job

    def initialize
      # 设置默认值
      @cache_repo = {}
      @prebuild_config = 'Debug'
      @prebuild_sandbox_path = '_Prebuild'
      @xcframework = true
      @artifact_hash_factors = [:source, :dependencies, :build_settings]
      @prebuild_job = false
    end

    # 更新配置
    #
    # @param options [Hash] 配置选项
    # @option options [Hash] :cache_repo 缓存仓库配置
    # @option options [String] :prebuild_config 预编译配置
    # @option options [String] :prebuild_sandbox_path 沙盒路径
    # @option options [Boolean] :xcframework 是否启用 xcframework
    # @option options [Array<Symbol>] :artifact_hash_factors 哈希因子
    def update(options)
      @cache_repo = options[:cache_repo] if options[:cache_repo]
      @prebuild_config = options[:prebuild_config] if options[:prebuild_config]
      @prebuild_sandbox_path = options[:prebuild_sandbox_path] if options[:prebuild_sandbox_path]
      @xcframework = options[:xcframework] if options.key?(:xcframework)
      @artifact_hash_factors = options[:artifact_hash_factors] if options[:artifact_hash_factors]
    end

    # 获取缓存路径
    #
    # @param repo_name [String] 仓库名称，默认为 "default"
    # @return [String] 缓存路径
    def cache_path(repo_name = 'default')
      repo_config = @cache_repo[repo_name]
      return nil unless repo_config

      path = repo_config['local']
      File.expand_path(path) if path
    end

    # 获取 Artifact 存储路径
    #
    # @return [String] Artifact 存储目录
    def artifacts_path
      return nil unless cache_path

      File.join(cache_path, 'artifacts')
    end

    # 获取当前框架路径（符号链接目录）
    #
    # @return [String] 当前框架路径
    def current_frameworks_path
      File.join(@prebuild_sandbox_path, 'current')
    end

    # 验证配置
    #
    # @raise [StandardError] 如果配置无效
    def validate!
      raise '缺少缓存仓库配置 cache_repo' if @cache_repo.empty?
      raise '缓存路径未配置' unless cache_path
    end
  end
end
