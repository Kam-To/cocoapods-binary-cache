module PodPrebuild
  class PreInstallHook
    attr_reader :installer_context, :podfile, :prebuild_sandbox, :standard_sandbox

    def initialize(installer_context)
      @installer_context = installer_context
      @podfile = installer_context.podfile
      @prebuild_sandbox = nil
      @standard_sandbox = installer_context.sandbox
    end

    def run
      return if @installer_context.sandbox.is_a?(Pod::PrebuildSandbox)

      PodPrebuild::Env.reset!
      PodPrebuild.state.update(:cache_validation => CacheValidationResult.new, :artifacts => {})

      log_section "🚀  Prebuild frameworks"
      ensure_valid_podfile
      create_prebuild_sandbox
      require_relative "../pod-binary/integration"
    end

    private

    def ensure_valid_podfile
      podfile.target_definition_list.each do |target_definition|
        next if target_definition.explicit_prebuilt_pod_names.empty?
        raise "cocoapods-binary-cache requires `use_frameworks!`" unless target_definition.uses_frameworks?
      end
    end

    def create_prebuild_sandbox
      @prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(standard_sandbox)
      Pod::UI.message "Create prebuild sandbox at #{@prebuild_sandbox.root}"
    end

    def log_section(message)
      Pod::UI.puts "-----------------------------------------"
      Pod::UI.puts message
      Pod::UI.puts "-----------------------------------------"
    end
  end
end
