require "spec_helper"
require "json"
require_relative "../../../lib/cocoapods-binary-cache/cache/artifact_cache_manager"

RSpec.describe PodPrebuild::ArtifactCacheManager do
  FakeConfig = Struct.new(:cache_path, :prebuild_sandbox_path)

  class FakeArtifact
    attr_reader :artifact_id, :name

    def initialize(artifact_id:, name: "SamplePod")
      @artifact_id = artifact_id
      @name = name
    end

    def generate_metadata
      { :name => name, :artifact_id => artifact_id }
    end
  end

  def artifact_dir(cache_root, artifact)
    File.join(cache_root, "artifacts", artifact.artifact_id)
  end

  it "skips republishing when the framework already resolves into the same artifact directory" do
    Dir.mktmpdir do |dir|
      cache_root = File.join(dir, "cache")
      prebuild_root = File.join(dir, "prebuild")
      config = FakeConfig.new(cache_root, prebuild_root)
      manager = described_class.new(config)
      artifact = FakeArtifact.new(:artifact_id => "SamplePod-1.0.0-abc123")
      artifact_root = artifact_dir(cache_root, artifact)
      cached_framework = File.join(artifact_root, "SamplePod.xcframework")
      current_framework = File.join(prebuild_root, "current", "SamplePod", "SamplePod.xcframework")

      FileUtils.mkdir_p(artifact_root)
      FileUtils.mkdir_p(File.dirname(current_framework))
      FileUtils.mkdir_p(cached_framework)
      FileUtils.ln_s(cached_framework, current_framework)

      expect do
        manager.publish_artifact(artifact, current_framework)
      end.not_to raise_error

      expect(File.exist?(File.join(artifact_root, "metadata.json"))).to be(false)
    end
  end

  it "publishes metadata for a fresh framework path" do
    Dir.mktmpdir do |dir|
      cache_root = File.join(dir, "cache")
      prebuild_root = File.join(dir, "prebuild")
      config = FakeConfig.new(cache_root, prebuild_root)
      manager = described_class.new(config)
      artifact = FakeArtifact.new(:artifact_id => "SamplePod-1.0.0-def456")
      fresh_framework = File.join(dir, "SamplePod.xcframework")

      FileUtils.mkdir_p(fresh_framework)

      manager.publish_artifact(artifact, fresh_framework)

      metadata_path = File.join(artifact_dir(cache_root, artifact), "metadata.json")
      expect(File.exist?(metadata_path)).to be(true)
      expect(JSON.parse(File.read(metadata_path))).to include("artifact_id" => artifact.artifact_id)
    end
  end

  it "publishes support files from the staging directory into the artifact directory" do
    Dir.mktmpdir do |dir|
      cache_root = File.join(dir, "cache")
      prebuild_root = File.join(dir, "prebuild")
      config = FakeConfig.new(cache_root, prebuild_root)
      manager = described_class.new(config)
      artifact = FakeArtifact.new(:artifact_id => "SamplePod-1.0.0-res123")
      pod_dir = File.join(prebuild_root, "current", "SamplePod")
      framework_path = File.join(pod_dir, "SamplePod.xcframework")
      bundle_path = File.join(pod_dir, "SamplePodResources.bundle")
      marker_path = File.join(pod_dir, "SamplePod.pod_name")

      FileUtils.mkdir_p(framework_path)
      FileUtils.mkdir_p(bundle_path)
      File.write(marker_path, "")

      manager.publish_artifact(artifact, framework_path)

      artifact_root = artifact_dir(cache_root, artifact)
      expect(File.directory?(File.join(artifact_root, "SamplePod.xcframework"))).to be(true)
      expect(File.directory?(File.join(artifact_root, "SamplePodResources.bundle"))).to be(true)
      expect(File.exist?(File.join(artifact_root, "SamplePod.pod_name"))).to be(false)
      expect(File.exist?(File.join(artifact_root, "metadata.json"))).to be(true)
    end
  end

  it "does not recreate the prebuild current directory for local hits" do
    Dir.mktmpdir do |dir|
      cache_root = File.join(dir, "cache")
      prebuild_root = File.join(dir, "prebuild")
      config = FakeConfig.new(cache_root, prebuild_root)
      manager = described_class.new(config)
      artifact = FakeArtifact.new(:artifact_id => "SamplePod-1.0.0-hit123")
      artifact_root = artifact_dir(cache_root, artifact)
      framework_path = File.join(artifact_root, "SamplePod.xcframework")

      FileUtils.mkdir_p(framework_path)
      File.write(File.join(artifact_root, "metadata.json"), JSON.pretty_generate("artifact_id" => artifact.artifact_id))

      expect(manager.fetch_artifact(artifact)).to eq(:local_hit)
      expect(File.exist?(File.join(prebuild_root, "current"))).to be(false)
    end
  end
end
