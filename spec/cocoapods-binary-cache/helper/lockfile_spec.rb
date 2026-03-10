require "spec_helper"
require_relative "../../../lib/cocoapods-binary-cache/helper/lockfile"

RSpec.describe PodPrebuild::Lockfile do
  FakeLockfile = Struct.new(:payload, :defined_in_file) do
    def to_hash
      payload
    end
  end

  it "detects dev pods from symbol and string path keys" do
    lockfile = FakeLockfile.new(
      {
        "PODS" => ["DevPod (1.0.0)", "StringDevPod (1.0.0)"],
        "EXTERNAL SOURCES" => {
          "DevPod" => { :path => "../local/DevPod" },
          "StringDevPod" => { ":path" => "../local/StringDevPod" }
        }
      },
      "/tmp/Podfile.lock"
    )

    wrapper = described_class.new(lockfile)

    expect(wrapper.dev_pod_names).to contain_exactly("DevPod", "StringDevPod")
  end

  it "produces the same dev pod hash for Podfile.lock and Manifest.lock" do
    Dir.mktmpdir do |dir|
      project_dir = File.join(dir, "Example")
      local_pod_dir = File.join(dir, "local_pod", "AmrCodec")
      FileUtils.mkdir_p(local_pod_dir)
      FileUtils.mkdir_p(File.join(project_dir, "Pods"))
      File.write(File.join(local_pod_dir, "codec.m"), "value = 1;\n")

      allow(Pod::Config.instance).to receive(:project_root).and_return(Pathname(project_dir))
      allow(Pod::Config.instance).to receive(:podfile).and_return(
        double("podfile", :defined_in_file => Pathname(File.join(project_dir, "Podfile")))
      )

      payload = {
        "PODS" => ["AmrCodec (0.0.1)"],
        "EXTERNAL SOURCES" => {
          "AmrCodec" => { :path => "../local_pod/AmrCodec" }
        }
      }

      podfile_lock = FakeLockfile.new(payload, File.join(project_dir, "Podfile.lock"))
      manifest_lock = FakeLockfile.new(payload, File.join(project_dir, "Pods", "Manifest.lock"))

      podfile_hash = described_class.new(podfile_lock).dev_pod_hash("AmrCodec")
      manifest_hash = described_class.new(manifest_lock).dev_pod_hash("AmrCodec")

      expect(podfile_hash).to eq(manifest_hash)
    end
  end

  it "folds subspec-only entries back onto root pod names" do
    lockfile = FakeLockfile.new(
      {
        "PODS" => [
          "Lynx/Framework (3.4.1)",
          "Lynx/ReleaseResource (3.4.1)",
          "PrimJS/napi (2.14.0-rc.1)",
          "PrimJS/quickjs (2.14.0-rc.1)"
        ]
      },
      "/tmp/Podfile.lock"
    )

    wrapper = described_class.new(lockfile)

    expect(wrapper.pods["Lynx"]).to eq("3.4.1")
    expect(wrapper.pods["PrimJS"]).to eq("2.14.0-rc.1")
    expect(wrapper.pods["Lynx/Framework"]).to eq("3.4.1")
    expect(wrapper.pods["PrimJS/napi"]).to eq("2.14.0-rc.1")
  end
end
