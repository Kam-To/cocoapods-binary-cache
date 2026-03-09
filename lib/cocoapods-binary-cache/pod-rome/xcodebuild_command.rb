require_relative "xcodebuild_raw"

module PodPrebuild
  class XcodebuildCommand # rubocop:disable Metrics/ClassLength
    def initialize(options)
      @options = options
      case options[:targets][0].platform.name
      when :ios
        @options[:device] = "iphoneos"
        @options[:simulator] = "iphonesimulator"
      when :tvos
        @options[:device] = "appletvos"
        @options[:simulator] = "appletvsimulator"
      when :watchos
        @options[:device] = "watchos"
        @options[:simulator] = "watchsimulator"
      end
      @build_args = make_up_build_args(options[:args] || {})
    end

    def run
      sdks.each { |sdk| build_for_sdk(sdk) }

      targets.each do |target|
        create_xcframework(target)
      end
    end

    private

    def sdks
      @sdks ||= begin
        sdks_ = []
        sdks_ << simulator if build_types.include?(:simulator)
        sdks_ << device if build_types.include?(:device)
        sdks_
      end
    end

    def preferred_sdk
      @preferred_sdk ||= sdks.include?(device) ? device : sdks[0]
    end

    def build_types
      @build_types ||= [:simulator, :device]
    end

    def make_up_build_args(args)
      # Note: The build arguments explicitly passed from config_cocoapods_binary_cache
      # should be preceded by the default arguments so that they could take higher priority
      # when there are argument collisions in the xcodebuild command.
      # For ex. `xcodebuild AN_ARG=1 AN_ARG=2` should use `AN_ARG=2` instead.
      args_ = args.clone
      args_[:default] ||= []
      args_[:simulator] ||= []
      args_[:device] ||= []
      args_[:simulator].prepend("ARCHS=x86_64", "ONLY_ACTIVE_ARCH=NO") if simulator == "iphonesimulator"
      args_[:simulator] += args_[:default]
      args_[:device].prepend("ONLY_ACTIVE_ARCH=NO")
      args_[:device] += args_[:default]
      args_
    end

    def build_for_sdk(sdk)
      PodPrebuild::XcodebuildCommand.xcodebuild(
        sandbox: sandbox,
        scheme: scheme,
        targets: targets.map(&:label),
        configuration: configuration,
        sdk: sdk,
        deployment_target: targets.map { |t| t.platform.deployment_target }.max.to_s,
        log_path: log_path(sdk),
        args: sdk == simulator ? @build_args[:simulator] : @build_args[:device]
      )
    end

    def create_xcframework(target)
      non_framework_paths = Dir[target_products_dir_of(target, preferred_sdk) + "/*"] \
        - [framework_path_of(target, preferred_sdk)] \
        - dsym_paths_of(target, preferred_sdk) \
        - bcsymbolmap_paths_of(target, preferred_sdk)
      collect_output(target, non_framework_paths)

      output = "#{output_path(target)}/#{target.product_module_name}.xcframework"
      FileUtils.rm_rf(output)

      cmd = ["xcodebuild", "-create-xcframework", "-allow-internal-distribution"]

      # for each sdk, the order of params must be -framework then -debug-symbols
      # to prevent duplicated file error when copying dSYMs
      sdks.each do |sdk|
        cmd << "-framework" << framework_path_of(target, sdk).shellescape
        dsyms = dsym_paths_of(target, sdk)
        cmd += dsyms.map { |dsym| "-debug-symbols #{dsym.shellescape}" }
      end

      cmd << "-output" << output

      Pod::UI.puts "- Create xcframework: #{target}".magenta
      Pod::UI.puts_indented "$ #{cmd.join(' ')}" unless PodPrebuild.config.silent_build?

      `#{cmd.join(" ")}`
    end

    def collect_output(target, paths)
      FileUtils.mkdir_p(output_path(target))
      paths = [paths] unless paths.is_a?(Array)
      paths.each do |path|
        FileUtils.rm_rf(File.join(output_path(target), File.basename(path)))
        FileUtils.cp_r(path, output_path(target))
      end
    end

    def target_products_dir_of(target, sdk)
      "#{build_dir}/#{configuration}-#{sdk}/#{target.name}"
    end

    def framework_path_of(target, sdk)
      "#{target_products_dir_of(target, sdk)}/#{target.product_module_name}.framework"
    end

    def dsym_paths_of(target, sdk)
      Dir["#{target_products_dir_of(target, sdk)}/*.dSYM"]
    end

    def bcsymbolmap_paths_of(target, sdk)
      Dir["#{target_products_dir_of(target, sdk)}/*.bcsymbolmap"]
    end

    def sandbox
      @options[:sandbox]
    end

    def build_dir
      @options[:build_dir]
    end

    def output_path(target)
      "#{@options[:output_path]}/#{target.label}"
    end

    def scheme
      @options[:scheme]
    end

    def targets
      @options[:targets]
    end

    def configuration
      @options[:configuration]
    end

    def device
      @options[:device] || "iphoneos"
    end

    def simulator
      @options[:simulator] || "iphonesimulator"
    end

    def log_path(sdk)
      @options[:log_path].nil? ? nil : "#{@options[:log_path]}_#{sdk}"
    end
  end
end
