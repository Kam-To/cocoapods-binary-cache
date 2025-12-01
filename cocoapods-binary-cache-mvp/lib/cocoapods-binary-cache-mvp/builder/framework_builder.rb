# frozen_string_literal: true

module CocoapodsBinaryCacheMVP
  # 框架构建器
  #
  # 负责使用 xcodebuild 构建 Pod 框架
  class FrameworkBuilder
    # 初始化构建器
    #
    # @param sandbox_path [String] 沙盒路径
    def initialize(sandbox_path)
      @sandbox_path = sandbox_path
      @config = CocoapodsBinaryCacheMVP.config
    end

    # 构建框架
    #
    # @param pod_name [String] Pod 名称
    # @param target [Pod::PodTarget] Pod target
    # @return [String, nil] 构建产物路径
    def build(pod_name, target)
      Pod::UI.puts "🔨 开始构建: #{pod_name}".cyan

      # 准备输出路径
      output_path = prepare_output_path(pod_name)

      # 构建命令
      build_command = create_build_command(target, output_path)

      # 执行构建
      success = system(build_command)

      if success
        Pod::UI.puts "✅ 构建成功: #{pod_name}".green
        find_framework(output_path, pod_name)
      else
        Pod::UI.warn "❌ 构建失败: #{pod_name}".red
        nil
      end
    end

    private

    # 准备输出路径
    #
    # @param pod_name [String] Pod 名称
    # @return [String] 输出路径
    def prepare_output_path(pod_name)
      output_path = File.join(@config.current_frameworks_path, pod_name)
      FileUtils.mkdir_p(output_path)
      output_path
    end

    # 创建构建命令
    #
    # @param target [Pod::PodTarget] Pod target
    # @param output_path [String] 输出路径
    # @return [String] 构建命令
    def create_build_command(target, output_path)
      scheme = target.label
      configuration = @config.prebuild_config

      if @config.xcframework
        # 构建 xcframework
        create_xcframework_command(scheme, configuration, output_path)
      else
        # 构建普通 framework
        create_framework_command(scheme, configuration, output_path)
      end
    end

    # 创建 xcframework 构建命令
    #
    # @param scheme [String] scheme 名称
    # @param configuration [String] 配置（Debug/Release）
    # @param output_path [String] 输出路径
    # @return [String] 构建命令
    def create_xcframework_command(scheme, configuration, output_path)
      # 简化实现：只构建模拟器架构
      <<~CMD.strip
        set -e
        cd #{@sandbox_path}

        # 构建模拟器
        xcodebuild build \
          -workspace Pods.xcworkspace \
          -scheme "#{scheme}" \
          -configuration #{configuration} \
          -sdk iphonesimulator \
          -destination 'generic/platform=iOS Simulator' \
          BUILD_DIR="#{output_path}/build" \
          CONFIGURATION_BUILD_DIR="#{output_path}/build/simulator" \
          > /dev/null 2>&1

        # 创建 xcframework
        FRAMEWORK_PATH="#{output_path}/build/simulator/#{scheme}.framework"
        if [ -d "$FRAMEWORK_PATH" ]; then
          xcodebuild -create-xcframework \
            -framework "$FRAMEWORK_PATH" \
            -output "#{output_path}/#{scheme}.xcframework" \
            > /dev/null 2>&1
        fi

        # 清理临时文件
        rm -rf "#{output_path}/build"
      CMD
    end

    # 创建 framework 构建命令
    #
    # @param scheme [String] scheme 名称
    # @param configuration [String] 配置
    # @param output_path [String] 输出路径
    # @return [String] 构建命令
    def create_framework_command(scheme, configuration, output_path)
      <<~CMD.strip
        cd #{@sandbox_path} && \
        xcodebuild build \
          -workspace Pods.xcworkspace \
          -scheme "#{scheme}" \
          -configuration #{configuration} \
          -sdk iphonesimulator \
          BUILD_DIR="#{output_path}" \
          CONFIGURATION_BUILD_DIR="#{output_path}" \
          > /dev/null 2>&1
      CMD
    end

    # 查找构建产物
    #
    # @param output_path [String] 输出路径
    # @param pod_name [String] Pod 名称
    # @return [String, nil] 框架路径
    def find_framework(output_path, pod_name)
      # 查找 xcframework
      xcframework = Dir.glob(File.join(output_path, '*.xcframework')).first
      return xcframework if xcframework

      # 查找 framework
      framework = Dir.glob(File.join(output_path, '*.framework')).first
      return framework if framework

      nil
    end
  end
end
