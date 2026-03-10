module PodPrebuild
  class ResolvedLockfile
    attr_reader :defined_in_file

    def self.from_specs(resolved_specs, original_lockfile = nil)
      new(resolved_specs, original_lockfile)
    end

    def initialize(resolved_specs, original_lockfile = nil)
      @resolved_versions = {}
      resolved_specs.each do |spec|
        root_name = spec.name.split('/').first
        @resolved_versions[root_name] ||= spec.version.to_s
      end

      original_hash = original_lockfile ? original_lockfile.to_hash : {}
      @external_sources = original_hash["EXTERNAL SOURCES"] || {}
      @defined_in_file = original_lockfile&.defined_in_file
    end

    def to_hash
      pods_array = @resolved_versions.map { |name, version| "#{name} (#{version})" }
      {
        "PODS" => pods_array,
        "EXTERNAL SOURCES" => @external_sources
      }
    end
  end
end
