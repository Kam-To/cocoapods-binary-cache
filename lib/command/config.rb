# ========================================
# 文件说明: 插件配置管理核心类
# ========================================
# 这个文件定义了整个插件的配置系统，是理解插件行为的关键。
#
# 配置系统设计：
# 1. 单例模式：全局只有一个 Config 实例
# 2. 配置 dsl_config: Podfile 中的 config_cocoapods_binary_cache
#
# 设计理念：
# - 所有配置都在 Podfile 中定义，保证配置的一致性和可追溯性
# - 不支持命令行参数覆盖配置
#
# 核心配置项：
# - cache_path: 本地缓存路径
# - prebuild_config: 编译配置（Debug/Release）
# - excluded_pods: 不进行预编译的 pods
# - xcframework: 是否使用 xcframework 格式
# ========================================

module PodPrebuild
  # 便捷访问全局配置实例的方法
  # @return [PodPrebuild::Config] 配置单例
  def self.config
    PodPrebuild::Config.instance
  end

  # 配置类 - 管理插件的所有配置项
  #
  # 这个类负责：
  # 1. 读取和合并多个来源的配置
  # 2. 提供便捷的配置访问方法
  # 3. 验证配置的有效性
  # 4. 提供配置默认值
  class Config
    # 配置存储
    # @!attribute [rw] dsl_config
    #   @return [Hash] 来自 Podfile 中 config_cocoapods_binary_cache 的配置
    attr_accessor :dsl_config

    # 初始化配置对象
    # - dsl_config: 空 Hash，稍后由 Podfile 填充
    def initialize
      @dsl_config = {}
      @detected_config = {}
    end

    # 获取配置单例
    # @return [PodPrebuild::Config] 全局唯一的配置实例
    #
    # 这是单例模式的实现：
    # - 第一次调用时创建实例
    # - 后续调用返回同一个实例
    def self.instance
      @instance ||= new()
    end

    # 重置所有配置（主要用于测试）
    # 清空所有配置，恢复初始状态
    def reset!
      @dsl_config = {}
    end

    # ========================================
    # 本地缓存路径配置
    # ========================================

    # 获取本地缓存路径
    # @return [String] 本地缓存目录的绝对路径
    #
    # 默认值: "~/.cocoapods-binary-cache/prebuilt-frameworks"
    # 这个目录用于存储本地缓存
    def cache_path
      @cache_path ||= File.expand_path(@dsl_config[:cache_path] || "~/.cocoapods-binary-cache/prebuilt-frameworks")
    end

    # ========================================
    # 预编译路径配置
    # ========================================

    # 预编译沙盒路径
    # @return [String] 存放预编译中间产物的目录
    #
    # 默认值: "_Prebuild"
    # 目录结构:
    #   _Prebuild/
    #   ├── current/          # 当前使用的预编译框架（符号链接）
    #   │   └── AFNetworking/
    #   │       └── AFNetworking.xcframework -> ../../artifacts/...
    #   └── Pods/             # 预编译时的临时 Pods 目录
    def prebuild_sandbox_path
      @dsl_config[:prebuild_sandbox_path] || "_Prebuild"
    end

    # 获取预编译产物的最终存放路径
    # @param path [String, nil] 可选的子路径
    # @return [String] 预编译框架的存放路径
    #
    # 默认值: "_Prebuilt"
    # 如果启用了 xcframework，会自动将 .framework 扩展名转换为 .xcframework
    #
    # 示例:
    #   prebuilt_path                    # => "_Prebuilt"
    #   prebuilt_path(path: "AFNetworking.framework")  # => "_Prebuilt/AFNetworking.xcframework" (如果启用 xcframework)
    def prebuilt_path(path: nil)
      p = Pathname.new(path.nil? ? "_Prebuilt" : "_Prebuilt/#{path}")
      p = p.sub_ext(".xcframework") if xcframework? && p.extname == ".framework"
      p.to_s
    end

    # ========================================
    # 配置验证
    # ========================================

    # 验证 DSL 配置的有效性
    # 检查用户在 Podfile 中配置的选项是否正确
    #
    # 如果发现无效选项，会打印警告信息，但不会中断执行
    # 这是为了保证向前兼容性
    def validate_dsl_config
      inapplicable_options = @dsl_config.keys - applicable_dsl_config
      return if inapplicable_options.empty?

      message = <<~HEREDOC
        [WARNING] The following options (in `config_cocoapods_binary_cache`) are not correct: #{inapplicable_options}.
        Available options: #{applicable_dsl_config}.
        Check out the following doc for more details
          https://github.com/grab/cocoapods-binary-cache/blob/master/docs/configure_cocoapods_binary_cache.md
      HEREDOC

      Pod::UI.puts message.yellow
    end

    # ========================================
    # 预编译行为配置
    # ========================================

    # 获取预编译配置（Debug/Release/Custom）
    # @return [String] 编译配置名称
    #
    # 默认值: "Debug"
    # 这决定了使用哪个 build configuration 来预编译
    #
    # 示例:
    #   config_cocoapods_binary_cache(prebuild_config: "Release")  # => "Release"
    def prebuild_config
      @dsl_config[:prebuild_config] || "Debug"
    end

    # 是否处于预编译任务中
    # @return [Boolean] true 表示当前正在执行 prebuild 命令
    #
    # 这个标志用于区分：
    # - prebuild 任务: 需要编译框架
    # - 普通 install 任务: 只需要使用缓存
    def prebuild_job?
      @dsl_config[:prebuild_job]
    end

    # 是否预编译所有 binary pods（忽略缓存验证）
    # @return [Boolean] true 表示强制重新编译所有 pods
    #
    # 使用场景:
    # - 缓存损坏时重建所有缓存
    # - 强制更新所有预编译产物
    #
    # 在 Podfile 中配置:
    #   config_cocoapods_binary_cache(prebuild_all_pods: true)
    def prebuild_all_pods?
      @dsl_config[:prebuild_all_pods]
    end

    # 获取排除的 pods 列表
    # @return [Set<String>] 不进行预编译的 pod 名称集合
    #
    # 合并两个来源：
    # 1. 用户显式配置的排除列表 (dsl_config)
    # 2. 系统自动检测的排除列表 (detected_config)
    #    例如: 只有头文件的 pods
    def excluded_pods
      ((@dsl_config[:excluded_pods] || Set.new) + (@detected_config[:excluded_pods] || Set.new)).to_set
    end

    # ========================================
    # 编译选项配置
    # ========================================

    # 是否启用开发 pods 的预编译
    # @return [Boolean] true 表示也预编译本地开发的 pods
    #
    # 开发 pods 是指通过 :path 引入的本地 pods:
    #   pod 'MyLocalPod', :path => '../MyLocalPod', :binary => true
    def dev_pods_enabled?
      @dsl_config[:dev_pods_enabled]
    end

    # 是否启用真机编译
    # @return [Boolean] true 表示为真机设备编译
    #
    # false: 只为模拟器编译（更快，但不能用于真机）
    # true: 为真机和模拟器都编译（使用 xcframework）
    def device_build_enabled?
      @dsl_config[:device_build_enabled]
    end

    # 是否使用 XCFramework 格式
    # @return [Boolean] true 表示生成 .xcframework 而非 .framework
    #
    # XCFramework 的优势:
    # - 同时支持模拟器和真机
    # - 支持多个架构（x86_64, arm64, arm64-simulator）
    def xcframework?
      @dsl_config[:xcframework]
    end

    # 是否保留源代码
    # @return [Boolean] true 表示不删除源码
    #
    # 默认行为: 预编译后删除源码以节省空间
    # 启用此选项: 保留源码，便于调试
    def dont_remove_source_code?
      @dsl_config[:dont_remove_source_code]
    end

    # ========================================
    # 日志和调试配置
    # ========================================

    # xcodebuild 日志输出路径
    # @return [String, nil] 日志文件路径
    #
    # 如果配置了此路径，xcodebuild 的输出会重定向到该文件
    def xcodebuild_log_path
      @dsl_config[:xcodebuild_log_path]
    end

    # 自定义编译参数
    # @return [String, nil] 传递给 xcodebuild 的额外参数
    #
    # 示例: "SWIFT_OPTIMIZATION_LEVEL=-Osize"
    def build_args
      @dsl_config[:build_args]
    end

    # 缓存验证结果保存路径
    # @return [String, nil] 保存验证结果的文件路径
    #
    # 用于调试缓存命中/未命中的原因
    def save_cache_validation_to
      @dsl_config[:save_cache_validation_to]
    end

    # 是否验证预编译设置
    # @return [Boolean] true 表示检查预编译框架的编译设置
    def validate_prebuilt_settings
      @dsl_config[:validate_prebuilt_settings]
    end

    # 预编译时的代码生成钩子
    # @return [Proc, nil] 代码生成回调
    def prebuild_code_gen
      @dsl_config[:prebuild_code_gen]
    end

    # 是否启用严格诊断模式
    # @return [Boolean] true 表示输出更详细的调试信息
    def strict_diagnosis?
      @dsl_config[:strict_diagnosis]
    end

    # 是否静默编译（不输出编译日志）
    # @return [Boolean] true 表示隐藏 xcodebuild 输出
    def silent_build?
      @dsl_config[:silent_build]
    end

    # ========================================
    # Artifact 缓存配置
    # ========================================

    # 计算 artifact 哈希时考虑的因素
    # @return [Array<Symbol>] 哈希因素列表
    #
    # 默认因素: [:source, :dependencies, :build_settings, :compiler_flags, :deployment_target]
    # 这些因素决定了什么情况下需要重新编译:
    # - source: 源码地址变化
    # - dependencies: 依赖关系变化
    # - build_settings: 编译设置变化
    # - compiler_flags: 编译器标志变化
    # - deployment_target: 部署目标版本变化
    def artifact_hash_factors
      @dsl_config[:artifact_hash_factors] || default_artifact_hash_factors
    end

    # 本地 artifact 保留策略
    # @return [Hash] 保留策略配置
    #
    # 示例配置:
    # {
    #   strategy: :lru,       # 使用 LRU (最近最少使用) 策略
    #   max_count: 50,        # 最多保留 50 个 artifacts
    #   max_size_mb: 5000     # 最多占用 5GB 空间
    # }
    def local_artifact_retention
      @dsl_config[:local_artifact_retention] || {}
    end

    # ========================================
    # 运行时检测配置（由插件自动更新）
    # ========================================

    # 更新检测到的预编译 pod 名称
    # @param value [Set<String>] pod 名称集合
    #
    # 这个方法由插件内部调用，记录实际被标记为 :binary => true 的 pods
    def update_detected_prebuilt_pod_names!(value)
      @detected_config[:prebuilt_pod_names] = value
    end

    # 更新检测到的排除 pods
    # @param value [Set<String>] pod 名称集合
    #
    # 这个方法由插件内部调用，记录自动排除的 pods（如只有头文件的 pods）
    def update_detected_excluded_pods!(value)
      @detected_config[:excluded_pods] = value
    end

    # 获取预编译的 pod 名称列表
    # @return [Set<String>] 所有被预编译的 pod 名称
    def prebuilt_pod_names
      @detected_config[:prebuilt_pod_names] || Set.new
    end

    # 获取实际跟踪的预编译 pod 名称（排除了 excluded_pods）
    # @return [Set<String>] 被跟踪的 pod 名称
    #
    # 这才是真正参与缓存管理的 pods 列表
    def tracked_prebuilt_pod_names
      prebuilt_pod_names - excluded_pods
    end

    private

    # 默认的 artifact 哈希因素
    # @return [Array<Symbol>] 默认因素列表
    def default_artifact_hash_factors
      [
        :source,              # 源码来源（Git URL、tag、commit）
        :dependencies,        # 依赖的其他 pods 及其版本
        :build_settings,      # Pod 的编译设置
        :compiler_flags,      # 编译器标志
        :deployment_target   # iOS/macOS 最低支持版本
      ]
    end

    # 可用的 DSL 配置选项列表
    # @return [Array<Symbol>] 有效的配置项名称
    #
    # 这个列表用于验证用户配置的有效性
    def applicable_dsl_config
      [
        :cache_path,                  # 本地缓存路径
        :prebuild_sandbox_path,       # 预编译沙盒路径
        :prebuild_config,             # 编译配置
        :prebuild_job,                # 是否为预编译任务（内部使用）
        :prebuild_all_pods,           # 是否编译所有 pods
        :excluded_pods,               # 排除的 pods
        :dev_pods_enabled,            # 是否支持开发 pods
        :device_build_enabled,        # 是否真机编译
        :xcframework,                 # 是否使用 XCFramework
        :dont_remove_source_code,     # 是否保留源码
        :xcodebuild_log_path,         # 编译日志路径
        :build_args,                  # 自定义编译参数
        :save_cache_validation_to,    # 验证结果保存路径
        :validate_prebuilt_settings,  # 是否验证编译设置
        :prebuild_code_gen,           # 代码生成钩子
        :strict_diagnosis,            # 严格诊断模式
        :silent_build,                # 静默编译
        :artifact_hash_factors,       # Artifact 哈希因素
        :local_artifact_retention     # 本地缓存保留策略
      ]
    end
  end
end
