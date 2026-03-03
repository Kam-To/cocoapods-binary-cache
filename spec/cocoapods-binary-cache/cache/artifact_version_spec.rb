require "spec_helper"
require_relative "../../../lib/cocoapods-binary-cache/cache/artifact_version"

RSpec.describe PodPrebuild::ArtifactVersion do
  Dependency = Struct.new(:name, :requirement)
  Platform = Struct.new(:name)

  class FakeSpec
    attr_reader :version, :source

    def initialize(version:, source:, dependencies: [])
      @version = version
      @source = source
      @dependencies = dependencies
    end

    def dependencies
      @dependencies
    end

    def available_platforms
      [Platform.new(:ios)]
    end

    def deployment_target(_platform)
      "13.0"
    end
  end

  let(:spec) do
    FakeSpec.new(
      version: "1.0.0",
      source: { :git => "https://example.com/repo.git", :tag => "1.0.0" },
      dependencies: [Dependency.new("Reachability", "~> 3.0")]
    )
  end

  it "returns the same artifact id for the same inputs" do
    first = described_class.generate("SamplePod", "1.0.0", spec, { "SWIFT_VERSION" => "5.0" }, ["Reachability:3.2"])
    second = described_class.generate("SamplePod", "1.0.0", spec, { "SWIFT_VERSION" => "5.0" }, ["Reachability:3.2"])

    expect(first).to eq(second)
  end

  it "changes the artifact id when resolved dependency versions change" do
    old_id = described_class.generate("SamplePod", "1.0.0", spec, {}, ["Reachability:3.1"])
    new_id = described_class.generate("SamplePod", "1.0.0", spec, {}, ["Reachability:3.2"])

    expect(new_id).not_to eq(old_id)
  end

  it "changes the artifact id when a dev pod source hash changes" do
    old_id = described_class.generate("SamplePod", "1.0.0", spec, {}, [], "abc123")
    new_id = described_class.generate("SamplePod", "1.0.0", spec, {}, [], "xyz789")

    expect(new_id).not_to eq(old_id)
  end

  it "uses a stable dev pod key when all dev pod inputs are unchanged" do
    first = described_class.generate("SamplePod", "1.0.0", spec, { "OTHER_CFLAGS" => "-DDEBUG" }, ["Reachability:3.2"], "abc123")
    second = described_class.generate("SamplePod", "1.0.0", spec, { "OTHER_CFLAGS" => "-DDEBUG" }, ["Reachability:3.2"], "abc123")

    expect(first).to eq(second)
  end
end
