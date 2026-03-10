module PodPrebuild
  class ArtifactReader
    attr_reader :artifact, :cache_manager

    def initialize(cache_manager, artifact)
      @cache_manager = cache_manager
      @artifact = artifact
    end

    def artifact_dir
      cache_manager.artifact_dir_for(artifact)
    end

    def available?
      artifact_dir.exist? && artifact_dir.directory?
    end

    def metadata
      cache_manager.metadata_for(artifact)
    end

    def framework_paths
      cache_manager.binary_paths_for(artifact)
    end

    def framework_path
      framework_paths.first
    end
  end
end
