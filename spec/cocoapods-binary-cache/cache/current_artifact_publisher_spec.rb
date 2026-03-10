require "spec_helper"
require "json"
require_relative "../../../lib/cocoapods-binary-cache/cache/current_artifact_publisher"

RSpec.describe PodPrebuild::CurrentArtifactPublisher do
  PublisherConfig = Struct.new(:cache_path, :prebuild_sandbox_path)

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

  class FakePrebuildSandbox
    def initialize(root:, pod_name:, target_name:)
      @root = Pathname(root)
      @pod_name = pod_name
      @target_name = target_name
    end

    def generate_framework_path
      @root
    end

    def exsited_framework_pod_names
      [@pod_name]
    end

    def existed_target_names_for_pod_name(pod_name)
      pod_name == @pod_name ? [@target_name] : []
    end

    def framework_folder_path_for_target_name(target_name)
      @root + target_name
    end
  end

  it "publishes the current target directory using the pod artifact mapping" do
    Dir.mktmpdir do |dir|
      cache_root = File.join(dir, "cache")
      current_root = File.join(dir, "current")
      pod_name = "SamplePod"
      target_name = "SamplePodTarget"
      sandbox = FakePrebuildSandbox.new(:root => current_root, :pod_name => pod_name, :target_name => target_name)
      artifact = FakeArtifact.new(:artifact_id => "SamplePod-1.0.0-pub123", :name => pod_name)
      framework_path = File.join(current_root, target_name, "SamplePod.xcframework")
      bundle_path = File.join(current_root, target_name, "SamplePodResources.bundle")
      marker_path = File.join(current_root, target_name, "#{pod_name}.pod_name")

      FileUtils.mkdir_p(framework_path)
      FileUtils.mkdir_p(bundle_path)
      FileUtils.mkdir_p(File.dirname(marker_path))
      File.write(marker_path, "")

      publisher = described_class.new(
        :config => PublisherConfig.new(cache_root, File.join(dir, "_Prebuild")),
        :prebuild_sandbox => sandbox,
        :artifacts_by_name => { pod_name => artifact }
      )

      expect(publisher.publish).to eq(1)

      artifact_root = File.join(cache_root, "artifacts", artifact.artifact_id)
      expect(File.directory?(File.join(artifact_root, "SamplePod.xcframework"))).to be(true)
      expect(File.directory?(File.join(artifact_root, "SamplePodResources.bundle"))).to be(true)
      expect(JSON.parse(File.read(File.join(artifact_root, "metadata.json")))).to include("artifact_id" => artifact.artifact_id)
    end
  end
end
