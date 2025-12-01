# frozen_string_literal: true

require 'fileutils'
require 'zip'

module CocoapodsBinaryCacheMVP
  # 缓存管理器
  #
  # 负责 Artifact 的存储、读取和清理
  class CacheManager
    # 初始化缓存管理器
    def initialize
      @config = CocoapodsBinaryCacheMVP.config
      ensure_cache_dir
    end

    # 发布 Artifact 到缓存
    #
    # @param artifact [Artifact] 要发布的 Artifact
    # @param framework_path [String] 框架文件路径
    # @return [Boolean] 是否成功
    def publish(artifact, framework_path)
      unless File.exist?(framework_path)
        Pod::UI.warn "框架文件不存在: #{framework_path}"
        return false
      end

      # 创建 Artifact 目录
      FileUtils.mkdir_p(artifact.cache_path)

      # 压缩框架文件
      zip_framework(framework_path, artifact.framework_cache_path)

      # 保存元数据
      save_metadata(artifact)

      Pod::UI.puts "✅ 发布成功: #{artifact}".green
      true
    rescue => e
      Pod::UI.warn "发布失败: #{e.message}"
      false
    end

    # 从缓存中拉取 Artifact
    #
    # @param artifact [Artifact] 要拉取的 Artifact
    # @param dest_path [String] 目标路径
    # @return [Boolean] 是否成功
    def fetch(artifact, dest_path)
      unless artifact.cached?
        Pod::UI.puts "缓存未命中: #{artifact.name}".yellow
        return false
      end

      # 解压框架文件
      unzip_framework(artifact.framework_cache_path, dest_path)

      Pod::UI.puts "✅ 使用缓存: #{artifact.name}".green
      true
    rescue => e
      Pod::UI.warn "拉取失败: #{e.message}"
      false
    end

    # 检查 Artifact 是否存在
    #
    # @param artifact [Artifact] 要检查的 Artifact
    # @return [Boolean] 是否存在
    def exists?(artifact)
      artifact.cached?
    end

    # 清理过期的 Artifacts
    #
    # @param max_count [Integer] 保留的最大数量
    def cleanup(max_count: 50)
      artifacts_dir = @config.artifacts_path
      return unless artifacts_dir && Dir.exist?(artifacts_dir)

      # 获取所有 Artifact 目录
      artifact_dirs = Dir.glob(File.join(artifacts_dir, '*')).select { |f| File.directory?(f) }

      # 按修改时间排序，保留最新的
      sorted_dirs = artifact_dirs.sort_by { |d| File.mtime(d) }.reverse

      # 删除超出数量的
      to_delete = sorted_dirs[max_count..-1] || []
      to_delete.each do |dir|
        FileUtils.rm_rf(dir)
        Pod::UI.puts "🗑️  清理: #{File.basename(dir)}"
      end

      Pod::UI.puts "清理完成，保留 #{[sorted_dirs.count, max_count].min} 个 Artifacts".green
    end

    private

    # 确保缓存目录存在
    def ensure_cache_dir
      artifacts_path = @config.artifacts_path
      FileUtils.mkdir_p(artifacts_path) if artifacts_path
    end

    # 压缩框架文件
    #
    # @param source_path [String] 源文件路径
    # @param zip_path [String] 压缩文件路径
    def zip_framework(source_path, zip_path)
      File.delete(zip_path) if File.exist?(zip_path)

      Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
        if File.directory?(source_path)
          # 压缩目录
          Dir[File.join(source_path, '**', '**')].each do |file|
            zipfile.add(file.sub(source_path + '/', ''), file)
          end
        else
          # 压缩单个文件
          zipfile.add(File.basename(source_path), source_path)
        end
      end
    end

    # 解压框架文件
    #
    # @param zip_path [String] 压缩文件路径
    # @param dest_path [String] 目标路径
    def unzip_framework(zip_path, dest_path)
      FileUtils.mkdir_p(dest_path)

      Zip::File.open(zip_path) do |zipfile|
        zipfile.each do |entry|
          entry_path = File.join(dest_path, entry.name)
          FileUtils.mkdir_p(File.dirname(entry_path))
          entry.extract(entry_path) { true }  # 覆盖已存在的文件
        end
      end
    end

    # 保存元数据
    #
    # @param artifact [Artifact] Artifact 对象
    def save_metadata(artifact)
      metadata_path = File.join(artifact.cache_path, 'metadata.json')
      File.write(metadata_path, JSON.pretty_generate(artifact.to_h))
    end
  end
end
