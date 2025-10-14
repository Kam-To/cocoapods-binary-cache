require "fourflusher"

module PodPrebuild
  class XcodebuildCommand
    PLATFORM_OF_SDK = {
      "iphonesimulator" => "iOS",
      "appletvsimulator" => "tvOS",
      "watchsimulator" => "watchOS"
    }.freeze

    DESTINATION_OF_SDK = {
      "iphoneos" => "\"generic/platform=iOS\"",
      "iphonesimulator" => "\"generic/platform=iOS Simulator\""
    }.freeze

    def self.xcodebuild(options)
      sdk = options[:sdk] || "iphonesimulator"
      targets = options[:targets] || [options[:target]]
      platform = PLATFORM_OF_SDK[sdk]

      # Check if using generate_multiple_pod_projects
      # In multi-project mode, each pod has its own .xcodeproj file
      sandbox_root = options[:sandbox].root
      target_projects = targets.map do |target|
        # Extract pod name from target label (e.g., "AFNetworking" from "AFNetworking" or "Pods-PodBinCacheExample")
        pod_name = target.to_s.split('-').first
        individual_project = sandbox_root + "#{pod_name}.xcodeproj"

        if individual_project.exist?
          individual_project.realdirpath.shellescape
        else
          options[:sandbox].project_path.realdirpath.shellescape
        end
      end.uniq

      # Build each project separately if using multi-project mode
      if target_projects.count > 1 || (target_projects.count == 1 && target_projects.first != options[:sandbox].project_path.realdirpath.shellescape)
        targets.each do |target|
          pod_name = target.to_s.split('-').first
          individual_project = sandbox_root + "#{pod_name}.xcodeproj"
          project_path = individual_project.exist? ? individual_project.realdirpath.shellescape : options[:sandbox].project_path.realdirpath.shellescape

          build_single_target(
            project_path: project_path,
            target: target,
            sdk: sdk,
            platform: platform,
            options: options
          )
        end
      else
        # Original single project build
        cmd = ["xcodebuild"]
        cmd << "-project" << options[:sandbox].project_path.realdirpath.shellescape
        targets.each { |target| cmd << "-target" << target }
        cmd << "-configuration" << options[:configuration].shellescape
        cmd << "-sdk" << sdk
        if DESTINATION_OF_SDK.key?(sdk)
          cmd << "-destination" << DESTINATION_OF_SDK[sdk]
        else
          unless platform.nil?
            cmd << Fourflusher::SimControl.new.destination(:oldest, platform, options[:deployment_target])
          end
        end
        cmd += options[:args] if options[:args]
        cmd << "build"

        if options[:log_path].nil?
          cmd << "2>&1"
        else
          FileUtils.mkdir_p(File.dirname(options[:log_path]))
          cmd << "> #{options[:log_path].shellescape}"
        end
        cmd = cmd.join(" ")

        Pod::UI.puts_indented "$ #{cmd}" unless PodPrebuild.config.silent_build?

        log = `#{cmd}`
        return if $?.exitstatus.zero? # rubocop:disable Style/SpecialGlobalVars

        begin
          require "xcpretty" # TODO (thuyen): Revise this dependency
          # use xcpretty to print build log
          # 64 represent command invalid. http://www.manpagez.com/man/3/sysexits/
          printer = XCPretty::Printer.new({:formatter => XCPretty::Simple, :colorize => "auto"})
          log.each_line do |line|
            printer.pretty_print(line)
          end
        rescue
          Pod::UI.puts log.red
        ensure
          raise "Fail to build targets: #{targets}"
        end
      end
    end

    def self.build_single_target(project_path:, target:, sdk:, platform:, options:)
      cmd = ["xcodebuild"]
      cmd << "-project" << project_path
      cmd << "-target" << target
      cmd << "-configuration" << options[:configuration].shellescape
      cmd << "-sdk" << sdk
      if DESTINATION_OF_SDK.key?(sdk)
        cmd << "-destination" << DESTINATION_OF_SDK[sdk]
      else
        unless platform.nil?
          cmd << Fourflusher::SimControl.new.destination(:oldest, platform, options[:deployment_target])
        end
      end
      cmd += options[:args] if options[:args]
      cmd << "build"

      if options[:log_path].nil?
        cmd << "2>&1"
      else
        FileUtils.mkdir_p(File.dirname(options[:log_path]))
        log_path = options[:log_path].to_s.sub(/(\.\w+)?$/, "_#{target}\\1")
        cmd << "> #{log_path.shellescape}"
      end
      cmd = cmd.join(" ")

      Pod::UI.puts_indented "$ #{cmd}" unless PodPrebuild.config.silent_build?

      log = `#{cmd}`
      return if $?.exitstatus.zero? # rubocop:disable Style/SpecialGlobalVars

      begin
        require "xcpretty" # TODO (thuyen): Revise this dependency
        printer = XCPretty::Printer.new({:formatter => XCPretty::Simple, :colorize => "auto"})
        log.each_line do |line|
          printer.pretty_print(line)
        end
      rescue
        Pod::UI.puts log.red
      ensure
        raise "Fail to build target: #{target}"
      end
    end
  end
end
