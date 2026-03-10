require "fileutils"

module PodPrebuild
  class PostInstallHook
    def initialize(installer_context)
      @installer_context = installer_context
    end

    def run
      return unless PodPrebuild::Env.integration_stage?

      remove_local_podspecs_for_external_prebuilt_pods
      prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(@installer_context.sandbox)
      return unless prebuild_sandbox.root.exist?

      FileUtils.rm_rf(prebuild_sandbox.root)
      Pod::UI.puts "Removed temporary prebuild sandbox: #{prebuild_sandbox.root}".yellow
    end

    private

    def remove_local_podspecs_for_external_prebuilt_pods
      PodPrebuild.config.prebuilt_pod_names.each do |name|
        @installer_context.sandbox.remove_local_podspec(name) if @installer_context.sandbox.checkout_sources.key?(name)
      end
    end
  end
end

Pod::HooksManager.register("cocoapods-binary-cache", :post_install) do |installer_context|
  PodPrebuild::PostInstallHook.new(installer_context).run
end
