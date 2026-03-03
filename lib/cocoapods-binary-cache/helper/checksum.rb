# Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
# Use of this source code is governed by an MIT-style license that can be found in the LICENSE file

require "digest/md5"

require "shellwords"

class FolderChecksum
  IGNORED_PATH_SEGMENTS = %w[_Prebuild _Prebuilt Pods].freeze
  IGNORED_BASENAMES = %w[.DS_Store].freeze

  def self.git_checksum(dir)
    root = File.realdirpath(dir)
    files = Dir.chdir(root) do
      `git ls-files --cached --others --exclude-standard .`.split("\n").map { |path| File.join(root, path) }
    end
    files = source_files(root) if files.empty?
    files = files.reject { |path| ignored_path?(path) }
    checksum_of_files(files)
  rescue => e
    if defined?(Pod::UI)
      Pod::UI.warn "Cannot get checksum of tracked files under #{dir}: #{e}"
    else
      warn "Cannot get checksum of tracked files under #{dir}: #{e}"
    end
    checksum_of_files(source_files(dir))
  end

  def self.checksum_of_files(files)
    checksums = files.sort.map { |f| Digest::MD5.hexdigest(File.read(f)) }
    Digest::MD5.hexdigest(checksums.join)
  end

  def self.source_files(dir)
    Dir["#{dir}/**/*"].reject { |path| File.directory?(path) || ignored_path?(path) }
  end

  def self.ignored_path?(path)
    path = path.to_s
    basename = File.basename(path)
    return true if IGNORED_BASENAMES.include?(basename)

    segments = path.split(File::SEPARATOR)
    (segments & IGNORED_PATH_SEGMENTS).any?
  end
end
