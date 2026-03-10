require "fileutils"

module PodPrebuild
  class PostInstallHook
    def initialize(installer_context)
      @installer_context = installer_context
    end

    def run
      return unless PodPrebuild::Env.integration_stage?

      prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(@installer_context.sandbox)
      return unless prebuild_sandbox.root.exist?

      FileUtils.rm_rf(prebuild_sandbox.root)
      Pod::UI.puts "Removed temporary prebuild sandbox: #{prebuild_sandbox.root}".yellow
    end
  end
end

Pod::HooksManager.register("cocoapods-binary-cache", :post_install) do |installer_context|
  PodPrebuild::PostInstallHook.new(installer_context).run
end
