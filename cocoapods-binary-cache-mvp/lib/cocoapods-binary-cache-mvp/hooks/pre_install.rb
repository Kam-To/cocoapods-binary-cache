# frozen_string_literal: true

module CocoapodsBinaryCacheMVP
  # Pre Install 钩子
  #
  # 在 pod install 执行前拦截，执行缓存验证和预编译逻辑
  class PreInstallHook
    # 初始化钩子
    #
    # @param installer_context [Pod::Installer::InstallationOptions::InstallerContext] 安装上下文
    def initialize(installer_context)
      @context = installer_context
      @podfile = installer_context.podfile
      @config = CocoapodsBinaryCacheMVP.config
    end

    # 执行钩子
    def run
      Pod::UI.section('🚀 CocoaPods Binary Cache MVP') do
        # 1. 检测预编译 Pods
        detect_prebuilt_pods

        # 2. 验证缓存
        validate_cache

        # 3. 如果是预编译任务，执行预编译
        prebuild_if_needed
      end
    end

    private

    # 检测标记为预编译的 Pods
    def detect_prebuilt_pods
      @prebuilt_pods = []

      @podfile.target_definitions.values.each do |target_definition|
        target_definition.dependencies.each do |dependency|
          # 检查是否标记为 :binary => true
          if dependency.external_source&.dig(:binary) == true ||
             dependency.podspec_repo&.dig(:binary) == true
            @prebuilt_pods << dependency.name
          end
        end
      end

      Pod::UI.puts "检测到 #{@prebuilt_pods.count} 个预编译 Pods: #{@prebuilt_pods.join(', ')}".cyan
    end

    # 验证缓存
    def validate_cache
      return if @prebuilt_pods.empty?

      # 获取 lockfile
      lockfile = @context.lockfile
      unless lockfile
        Pod::UI.warn "未找到 Podfile.lock，跳过缓存验证"
        return
      end

      # 创建验证器
      validator = CacheValidator.new(lockfile, @prebuilt_pods)
      @validation_result = validator.validate
    end

    # 如果需要，执行预编译
    def prebuild_if_needed
      # 只有在预编译任务时才执行
      return unless @config.prebuild_job

      missed_pods = @validation_result[:missed]
      return if missed_pods.empty?

      Pod::UI.section('开始预编译') do
        prebuild_pods(missed_pods)
      end
    end

    # 预编译 Pods
    #
    # @param pod_names [Set<String>] 需要预编译的 Pod 列表
    def prebuild_pods(pod_names)
      # 创建预编译沙盒
      sandbox_path = create_prebuild_sandbox

      # 执行 pod install（在预编译沙盒中）
      install_to_sandbox(sandbox_path)

      # 构建框架
      build_frameworks(sandbox_path, pod_names)

      # 发布到缓存
      publish_to_cache(pod_names)
    end

    # 创建预编译沙盒
    #
    # @return [String] 沙盒路径
    def create_prebuild_sandbox
      sandbox_path = @config.prebuild_sandbox_path
      FileUtils.mkdir_p(sandbox_path)
      Pod::UI.puts "创建预编译沙盒: #{sandbox_path}".cyan
      sandbox_path
    end

    # 在沙盒中安装 Pods
    #
    # @param sandbox_path [String] 沙盒路径
    def install_to_sandbox(sandbox_path)
      Pod::UI.puts "在沙盒中安装依赖...".cyan

      # 简化实现：复用当前安装结果
      # 在实际实现中，应该在沙盒中重新执行 pod install
      current_sandbox = @context.sandbox
      FileUtils.cp_r(current_sandbox.root, sandbox_path) unless sandbox_path == current_sandbox.root
    end

    # 构建框架
    #
    # @param sandbox_path [String] 沙盒路径
    # @param pod_names [Set<String>] Pod 列表
    def build_frameworks(sandbox_path, pod_names)
      builder = FrameworkBuilder.new(sandbox_path)

      # 获取 pod targets
      installer = Pod::Installer.new(
        Pod::Config.instance.sandbox,
        @podfile,
        @context.lockfile
      )
      installer.resolve_dependencies

      pod_names.each do |pod_name|
        target = installer.pod_targets.find { |t| t.pod_name == pod_name }
        next unless target

        builder.build(pod_name, target)
      end
    end

    # 发布到缓存
    #
    # @param pod_names [Set<String>] Pod 列表
    def publish_to_cache(pod_names)
      cache_manager = CacheManager.new
      validator = CacheValidator.new(@context.lockfile, pod_names.to_a)

      pod_names.each do |pod_name|
        artifact = validator.create_artifact(pod_name)
        next unless artifact

        # 查找构建产物
        framework_path = find_framework_in_output(pod_name)
        next unless framework_path

        # 发布到缓存
        cache_manager.publish(artifact, framework_path)
      end
    end

    # 在输出目录中查找框架
    #
    # @param pod_name [String] Pod 名称
    # @return [String, nil] 框架路径
    def find_framework_in_output(pod_name)
      output_dir = File.join(@config.current_frameworks_path, pod_name)
      return nil unless Dir.exist?(output_dir)

      # 查找 xcframework 或 framework
      Dir.glob(File.join(output_dir, '*.{xcframework,framework}')).first
    end
  end
end
