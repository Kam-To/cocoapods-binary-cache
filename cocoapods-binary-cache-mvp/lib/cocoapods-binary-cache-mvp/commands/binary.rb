# frozen_string_literal: true

module Pod
  class Command
    # Binary 主命令
    #
    # pod binary 命令的入口
    class Binary < Command
      # 这是一个抽象命令，包含子命令
      self.abstract_command = true
      self.summary = '二进制缓存管理命令'

      # 命令描述
      self.description = <<-DESC
        管理 CocoaPods 二进制缓存的命令集合。

        支持的子命令：
        - prebuild: 预编译 Pods 并缓存
      DESC
    end
  end
end
