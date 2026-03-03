require "spec_helper"
require_relative "../../../lib/cocoapods-binary-cache/helper/checksum"

RSpec.describe FolderChecksum do
  it "changes when tracked source files change" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "source.m"), "value = 1;\n")

      old_checksum = described_class.checksum_of_files(described_class.source_files(dir))

      File.write(File.join(dir, "source.m"), "value = 2;\n")
      new_checksum = described_class.checksum_of_files(described_class.source_files(dir))

      expect(new_checksum).not_to eq(old_checksum)
    end
  end

  it "ignores generated directories and metadata noise" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "source.m"), "value = 1;\n")
      FileUtils.mkdir_p(File.join(dir, "_Prebuild", "tmp"))
      FileUtils.mkdir_p(File.join(dir, "_Prebuilt", "tmp"))
      FileUtils.mkdir_p(File.join(dir, "Pods", "tmp"))
      File.write(File.join(dir, ".DS_Store"), "ignored")
      File.write(File.join(dir, "_Prebuild", "tmp", "artifact"), "ignored")
      File.write(File.join(dir, "_Prebuilt", "tmp", "artifact"), "ignored")
      File.write(File.join(dir, "Pods", "tmp", "artifact"), "ignored")

      checksum = described_class.checksum_of_files(described_class.source_files(dir))
      expected = described_class.checksum_of_files([File.join(dir, "source.m")])

      expect(checksum).to eq(expected)
    end
  end
end
