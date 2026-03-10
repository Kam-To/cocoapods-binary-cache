require_relative "cache/current_artifact_publisher"
require_relative "helper/resolved_lockfile"

module PodPrebuild
  class InstallerResolvePreparer
    attr_reader :installer

    def initialize(installer)
      @installer = installer
    end

    def prepare!
      Pod::UI.title("Detect implicit dependencies") { detect_implicit_dependencies }
      Pod::UI.title("Validate prebuilt cache") { validate_cache }
      prebuild_if_needed
      prepare_for_integration
    end

    private

    def detect_implicit_dependencies
      all_specs = installer.analysis_result.specifications
      pods_with_empty_source_files = all_specs
        .group_by { |spec| spec.name.split("/")[0] }
        .select { |_, specs| specs.all?(&:empty_source_files?) }
        .keys
      PodPrebuild.config.update_detected_excluded_pods!(pods_with_empty_source_files)
      PodPrebuild.config.update_detected_prebuilt_pod_names!(installer.prebuilt_pod_names)
      Pod::UI.puts "Exclude pods with empty source files: #{pods_with_empty_source_files.to_a}"
    end

    def validate_cache
      Pod::UI.puts "Using artifact-based cache validation".green

      validator = PodPrebuild::ArtifactsCacheValidator.new(
        pod_lockfile: resolved_lockfile,
        sandbox: installer.sandbox,
        validate_prebuilt_settings: PodPrebuild.config.validate_prebuilt_settings,
        ignored_pods: PodPrebuild.config.excluded_pods,
        prebuilt_pod_names: PodPrebuild.config.prebuilt_pod_names
      )

      cache_validation = validator.validate
      cache_validation.print_summary
      PodPrebuild.state.update(
        :cache_validation => cache_validation,
        :artifacts => validator.resolved_artifacts
      )
    end

    def prebuild_if_needed
      return unless PodPrebuild.config.prebuild_job?
      return unless PodPrebuild::Env.prebuild_stage?

      binary_installer = Pod::PrebuildInstaller.new(
        sandbox: prebuild_sandbox,
        podfile: installer.podfile,
        lockfile: installer.lockfile,
        cache_validation: PodPrebuild.state.cache_validation
      )
      binary_installer.update = installer.update
      binary_installer.repo_update = installer.repo_update

      Pod::UI.title("Prebuilding...") do
        binary_installer.install!
        publish_prebuilt_artifacts
      end

      PodPrebuild::Env.next_stage!
      log_section "🤖  Resume pod installation"
    end

    def publish_prebuilt_artifacts
      publisher = PodPrebuild::CurrentArtifactPublisher.new(
        config: PodPrebuild.config,
        prebuild_sandbox: prebuild_sandbox,
        artifacts_by_name: PodPrebuild.state.artifacts,
        lockfile: resolved_lockfile,
        sandbox: installer.sandbox,
        build_settings_provider: PodPrebuild.config.validate_prebuilt_settings
      )
      published_count = publisher.publish
      Pod::UI.puts "Published #{published_count} artifact(s) for integration".green
    end

    def prepare_for_integration
      PodPrebuild.config.prebuilt_pod_names.each do |name|
        installer.sandbox.remove_local_podspec(name) if installer.sandbox.checkout_sources.key?(name)
      end
    end

    def prebuild_sandbox
      @prebuild_sandbox ||= Pod::PrebuildSandbox.from_standard_sandbox(installer.sandbox)
    end

    def resolved_lockfile
      @resolved_lockfile ||= PodPrebuild::ResolvedLockfile.from_specs(
        installer.analysis_result.specifications,
        installer.lockfile
      )
    end

    def log_section(message)
      Pod::UI.puts "-----------------------------------------"
      Pod::UI.puts message
      Pod::UI.puts "-----------------------------------------"
    end
  end
end
