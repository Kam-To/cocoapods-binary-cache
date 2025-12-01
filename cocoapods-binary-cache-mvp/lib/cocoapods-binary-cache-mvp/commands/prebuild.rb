# frozen_string_literal: true

require_relative 'binary'

module Pod
  class Command
    class Binary < Command
      # Prebuild 子命令
      #
      # 预编译 Pods 并缓存
      class Prebuild < Binary
        self.summary = '预编译 Pods 并缓存'

        self.description = <<-DESC
          预编译标记为 :binary => true 的 Pods，并将构建产物缓存起来。

          在后续的 pod install 中可以直接使用缓存，避免重复编译。
        DESC

        # 命令选项
        def self.options
          [
            ['--config=NAME', '指定构建配置（Debug/Release），默认为 Debug'],
            ['--clean', '清理过期的缓存']
          ].concat(super)
        end

        # 初始化命令
        #
        # @param argv [CLAide::ARGV] 命令行参数
        def initialize(argv)
          @config_name = argv.option('config', 'Debug')
          @should_clean = argv.flag?('clean')
          super
        end

        # 验证参数
        def validate!
          super
          help! '请先在 Podfile 中配置二进制缓存' unless configured?
        end

        # 执行命令
        def run
          # 更新配置
          update_config

          # 标记为预编译任务
          CocoapodsBinaryCacheMVP.config.prebuild_job = true

          # 执行 pod install（会触发 pre_install 钩子）
          Pod::UI.section('开始预编译') do
            install_pods
          end

          # 清理缓存（如果指定）
          clean_cache if @should_clean

          Pod::UI.puts "\n✅ 预编译完成！".green
          Pod::UI.puts "提示：现在可以运行 'pod install' 来使用缓存".cyan
        end

        private

        # 检查是否已配置
        #
        # @return [Boolean] 是否已配置
        def configured?
          config = CocoapodsBinaryCacheMVP.config
          !config.cache_repo.empty? && config.cache_path
        end

        # 更新配置
        def update_config
          config = CocoapodsBinaryCacheMVP.config
          config.update(prebuild_config: @config_name)

          Pod::UI.puts "使用配置: #{@config_name}".cyan
        end

        # 执行 pod install
        def install_pods
          installer = Pod::Installer.new(
            Pod::Config.instance.sandbox,
            Pod::Config.instance.podfile,
            Pod::Config.instance.lockfile
          )

          installer.install!
        end

        # 清理缓存
        def clean_cache
          Pod::UI.section('清理过期缓存') do
            cache_manager = CocoapodsBinaryCacheMVP::CacheManager.new
            cache_manager.cleanup(max_count: 50)
          end
        end
      end
    end
  end
end
