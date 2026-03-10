require "pathname"
require_relative "checksum"

module PodPrebuild
  class Lockfile
    attr_reader :lockfile, :data

    def initialize(lockfile)
      @lockfile = lockfile
      @data = lockfile.to_hash
    end

    def pods
      @pods ||= begin
        parsed_pods = (@data["PODS"] || []).map { |v| pod_from(v) }.to_h

        # Some lockfiles only list subspec entries (for example `Lynx/Framework`)
        # even though the build/publish pipeline resolves artifacts by root pod
        # name. Fold subspec versions back onto their root names when the root
        # entry is absent.
        parsed_pods.keys.select { |name| name.include?("/") }.each do |subspec_name|
          root_name = subspec_name.split("/").first
          parsed_pods[root_name] ||= parsed_pods[subspec_name]
        end

        parsed_pods
      end
    end

    def external_sources
      @data["EXTERNAL SOURCES"] || {}
    end

    def dev_pod_sources
      @dev_pod_sources ||= external_sources.select { |_, attributes| dev_pod_path_value(attributes) } || {}
    end

    def dev_pod_names
      # There are 2 types of external sources:
      # - Development pods: declared with `:path` option in Podfile, corresponding to `:path` in the Lockfile
      # - External remote pods: declared with `:git` option in Podfile, corresponding to `:git` in the Lockfile
      # --------------------
      # EXTERNAL SOURCES:
      #   ADevPod:
      #     :path: path/to/dev_pod
      #   AnExternalRemotePod:
      #     :git: git@remote_url
      #     :commit: abc1234
      # --------------------
      @dev_pod_names ||= dev_pod_sources.keys.to_set
    end

    def dev_pods
      dev_pod_names_ = dev_pod_names
      @dev_pods ||= pods.select { |name, _| dev_pod_names_.include?(name) }
    end

    def non_dev_pods
      dev_pod_names_ = dev_pod_names
      @non_dev_pods ||= pods.reject { |name, _| dev_pod_names_.include?(name) }
    end

    def subspec_vendor_pods
      dev_pod_names_ = dev_pod_names
      @subspec_vendor_pods ||= subspec_pods.reject { |name, _| dev_pod_names_.include?(name) }
    end

    # Return content hash (Hash the directory at source path) of a dev_pod
    # Return nil if it's not a dev_pod
    def dev_pod_hash(pod_name)
      dev_pod_hashes_map[pod_name]
    end

    private

    def subspec_pods
      @subspec_pods ||= pods.keys
        .select { |k| k.include?("/") }
        .group_by { |k| k.split("/")[0] }
    end

    # Generate a map between a dev_pod and it source hash
    def dev_pod_hashes_map
      @dev_pod_hashes_map ||=
        dev_pod_sources.map { |name, attribs| [name, FolderChecksum.git_checksum(resolve_dev_pod_path(dev_pod_path_value(attribs)))] }.to_h
    end

    def dev_pod_path_value(attributes)
      attributes[:path] || attributes[":path"] || attributes["path"]
    end

    def resolve_dev_pod_path(path)
      return path unless path

      source_path = Pathname(path)
      return source_path.to_s if source_path.absolute?

      project_root = Pod::Config.instance.project_root rescue nil
      return source_path.expand_path(project_root).to_s if project_root

      podfile_path = Pod::Config.instance.podfile&.defined_in_file rescue nil
      return source_path.expand_path(Pathname(podfile_path).dirname).to_s if podfile_path

      lockfile_path = lockfile.respond_to?(:defined_in_file) ? lockfile.defined_in_file : nil
      return source_path.expand_path(Pathname(lockfile_path).dirname).to_s if lockfile_path

      source_path.expand_path.to_s
    end

    # Parse an item under `PODS` section of a Lockfile
    # @param hash_or_string: an item under `PODS` section, could be a Hash (if having dependencies) or a String
    #   Examples:
    # --------------------------
    #   PODS:
    #     - FrameworkA (0.0.1)
    #     - FrameworkB (0.0.2):
    #       - DependencyOfB
    # -------------------------
    # @return [framework_name, version] (for ex. ["AFramework", "0.0.1"])
    def pod_from(hash_or_string)
      name_with_version = hash_or_string.is_a?(Hash) ? hash_or_string.keys[0] : hash_or_string
      match = name_with_version.match(/(\S+) \((\S+)\)/)
      [match[1], match[2]]
    end
  end
end
