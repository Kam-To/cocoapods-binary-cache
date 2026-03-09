# CocoaPods Binary Cache

[![Test](https://img.shields.io/github/workflow/status/grab/cocoapods-binary-cache/test)](https://img.shields.io/github/workflow/status/grab/cocoapods-binary-cache/test)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat&color=blue)](https://github.com/grab/cocoapods-binary-cache/blob/master/LICENSE)
[![Gem](https://img.shields.io/gem/v/cocoapods-binary-cache.svg?style=flat&color=blue)](https://rubygems.org/gems/cocoapods-binary-cache)

这是一个 CocoaPods 插件，用来把指定 pods 预编译成 `framework/xcframework`，并缓存到本地目录中复用，从而减少 `pod install` 后的编译时间。

当前仓库是基于原始 `grab/cocoapods-binary-cache` 的本地化改造版本，**现阶段只保留本地缓存能力，不再包含远端缓存仓库的 fetch / push 流程**。

## 环境要求

- Ruby: >= 2.4
- CocoaPods: >= 1.16.0

## 安装

### 通过 Bundler

在业务工程的 `Gemfile` 中加入：

```rb
gem "cocoapods-binary-cache", :git => "https://github.com/grab/cocoapods-binary-cache.git", :tag => "0.1.11"
```

然后执行：

```sh
bundle install
```

### 通过 RubyGems

```sh
gem install cocoapods-binary-cache
```

## 核心能力

- 基于 `:binary => true` 标记预编译 pods
- 通过本地 `artifact_id` 管理二进制产物
- 支持 `xcframework`
- 支持 `:path` 开发 pod 的本地源码变更感知
- 支持本地缓存目录的 LRU 清理策略

## 基本用法

### 1. 在 Podfile 中启用插件

```rb
plugin "cocoapods-binary-cache"
```

### 2. 配置本地缓存

当前使用 `cache_path` 指定本地缓存目录：

```rb
config_cocoapods_binary_cache(
  cache_path: "~/.cocoapods-binary-cache/prebuilt-frameworks",
  prebuild_config: "Release",
  xcframework: true,
  device_build_enabled: true
)
```

常用配置项：

- `cache_path`: 本地缓存目录
- `prebuild_config`: 预编译使用的 build configuration
- `xcframework`: 是否生成 `xcframework`
- `device_build_enabled`: 是否同时编译真机产物
- `dev_pods_enabled`: 是否允许 `:path` pod 进入预编译

### 3. 标记需要预编译的 pods

```rb
pod "AFNetworking", "3.2.1", :binary => true
pod "AmrCodec", :path => "../local_pod/AmrCodec", :binary => true
```

说明：

- 一个 pod 被标记为 `:binary => true` 后，其依赖会按当前解析结果一起参与缓存判定
- `:path` pod 会把本地源码目录内容纳入缓存 key；源码变更后会自动 miss 并重新预编译

### 4. 预编译

```sh
bundle exec pod binary prebuild
```

可选参数：

- `--repo-update`: 预编译前执行 repo update

### 5. 安装 pods

```sh
bundle exec pod install
```

推荐日常流程：

```sh
bundle exec pod binary prebuild
bundle exec pod install
```

## 缓存模型

当前实现是**本地 artifact 缓存**：

- 缓存目录由 `cache_path` 决定
- 每个产物以 `artifact_id` 作为目录名
- 命中时会从本地缓存链接到 `_Prebuild/current`
- 未命中时会重新编译并发布到本地缓存

`artifact_id` 的输入规则已经冻结，详见：

- [Artifact ID Rules](docs/artifact_id_rules.md)

## 测试与回归

仓库已经包含基础回归测试：

```sh
bundle exec rspec spec
```

还提供了集成测试脚本：

```sh
sh scripts/integration_test.sh
```

可选模式：

- `afnetworking-switch`
- `dev-pod-switch`
- `all`

## 示例工程

示例工程位于：

- [PodBinaryCacheExample](PodBinaryCacheExample)

它用于验证：

- 常规三方 pod 的缓存命中
- `:path` 开发 pod 的缓存 key 稳定性
- `xcframework` 预编译流程

## 已知限制

- 当前不支持远端缓存仓库同步
- 构建行为仍然依赖本地 Xcode / CocoaPods 环境
- 首次引入某个 pod 或 cache miss 时，仍需要执行真实预编译

## 许可证

本项目遵循 [MIT License](https://opensource.org/licenses/MIT)。
