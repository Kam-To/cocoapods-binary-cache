module PodPrebuild
  class CommandExecutor
    def initialize(options)
      @config = options[:config]
      prepare_cache_dir
    end

    def installer
      @installer ||= begin
        pod_config = Pod::Config.instance
        Pod::Installer.new(pod_config.sandbox, pod_config.podfile, pod_config.lockfile)
      end
    end

    def prepare_cache_dir
      FileUtils.mkdir_p(@config.cache_path) if @config.cache_path
    end
  end
end
