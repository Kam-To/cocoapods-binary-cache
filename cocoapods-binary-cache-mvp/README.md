# CocoaPods Binary Cache MVP

> 一个轻量级的 CocoaPods 二进制缓存插件，通过预编译 Pod 框架并缓存来加速构建。

## 📋 功能特性

- ✅ **基于 Artifact 的精确缓存**：通过内容哈希（SHA256）确保缓存准确性
- ✅ **支持 xcframework**：优先生成 xcframework，完美兼容 Apple Silicon Mac
- ✅ **本地缓存管理**：zip 压缩存储，节省磁盘空间
- ✅ **灵活配置**：可自定义哈希因子、缓存路径、构建配置等
- ✅ **中文注释**：代码注释详细，易于理解和二次开发
- ✅ **最小依赖**：仅依赖 CocoaPods 和 rubyzip，轻量级实现

## 🚀 快速开始

> 💡 **5 分钟快速上手**: 查看 [快速上手指南](快速上手.md) 立即开始使用！

### 安装

#### 方式 1: 本地安装（推荐开发）

```bash
# 克隆或下载本项目
cd cocoapods-binary-cache-mvp

# 构建并安装 gem
gem build cocoapods-binary-cache-mvp.gemspec
gem install cocoapods-binary-cache-mvp-0.1.0.gem
```

#### 方式 2: 通过 Gemfile（推荐团队）

在项目的 Gemfile 中添加：

```ruby
gem 'cocoapods-binary-cache-mvp', :path => './path/to/cocoapods-binary-cache-mvp'
```

然后运行：

```bash
bundle install
```

### 配置 Podfile

```ruby
# 加载插件
plugin 'cocoapods-binary-cache-mvp'

# 配置缓存
config_binary_cache({
  # 缓存根目录
  cache_path: "_Prebuild",

  # 预编译使用的配置（Debug 或 Release）
  prebuild_config: "Debug",

  # Artifact 哈希计算因子
  # 可选: :source, :dependencies, :build_settings, :compiler_flags, :deployment_target
  artifact_hash_factors: [:source, :dependencies],

  # 是否验证预编译设置
  validate_prebuilt_settings: false
})

# 标记需要预编译的 Pods
target 'YourApp' do
  use_frameworks!

  # 使用 :binary => true 标记预编译的 Pod
  pod 'Alamofire', '~> 5.6', :binary => true
  pod 'SnapKit', '~> 5.0', :binary => true
  pod 'RxSwift', '~> 6.5', :binary => true

  # 普通 Pod（不预编译）
  pod 'SwiftyJSON'
end
```

### 使用命令

```bash
# 1. 预编译所有标记为 :binary => true 的 Pods
pod binary prebuild

# 2. 使用指定配置预编译
pod binary prebuild --config=Release

# 3. 清理缓存后重新预编译
pod binary prebuild --clean

# 4. 日常开发：正常安装（自动使用缓存）
pod install

# 5. 清理所有缓存
pod binary clean
```

### 验证效果

执行 `pod install` 时会看到缓存验证结果：

```
🚀 CocoaPods Binary Cache MVP
检测到 3 个预编译 Pods: Alamofire, SnapKit, RxSwift

缓存验证结果:
✅ 命中缓存 (3):
  - Alamofire (Alamofire-a1b2c3d4e5f6g7h8)
  - SnapKit (SnapKit-x1y2z3a4b5c6d7e8)
  - RxSwift (RxSwift-m1n2o3p4q5r6s7t8)

❌ 缓存缺失 (0):
```

## 📂 目录结构

```
lib/cocoapods-binary-cache-mvp/
├── cache/              # 缓存系统
│   ├── artifact.rb     # Artifact 数据结构
│   ├── manager.rb      # 缓存管理器
│   └── validator.rb    # 缓存验证器
├── config/             # 配置管理
│   └── config.rb       # 全局配置
├── hooks/              # CocoaPods 钩子
│   └── pre_install.rb  # 安装前钩子
├── builder/            # 构建系统
│   └── framework_builder.rb  # 框架构建器
├── commands/           # CLI 命令
│   ├── binary.rb       # 主命令
│   └── prebuild.rb     # 预编译命令
└── plugin.rb           # 插件入口
```

## 🎯 工作原理

### 基本流程

1. **标记二进制 Pod**：在 Podfile 中使用 `:binary => true` 标记需要预编译的 Pod
2. **预编译阶段**：运行 `pod binary prebuild` 构建 framework/xcframework
3. **计算 Artifact ID**：基于源码 checksum、依赖、构建设置等计算唯一标识符
4. **存储缓存**：将构建产物压缩为 zip 并存储到 `_Prebuild/artifacts/`
5. **日常使用**：`pod install` 时自动检测缓存，命中则解压使用，缺失则源码编译

### Artifact ID 计算

```ruby
# 示例：Alamofire 的 Artifact ID 计算
hash_components = [
  "f1b72917a6b3...",           # :source - Pod checksum（来自 Podfile.lock）
  "RxSwift-6.5.0,SnapKit-5.0", # :dependencies - 依赖的 Pods
  "DEBUG=1,SWIFT_VERSION=5.0", # :build_settings - 构建设置
  # ... 其他因子
]

hash_string = hash_components.join('-')
hash_value = SHA256(hash_string)[0..15]  # 取前 16 位
artifact_id = "Alamofire-a1b2c3d4e5f6g7h8"
```

**关键**: 只有所有 hash_factors 都不变时，Artifact ID 才保持不变，才能命中缓存。

### 缓存目录结构

```
_Prebuild/
├── artifacts/                    # 压缩的缓存文件
│   ├── Alamofire-a1b2c3d4.zip   # 使用 Artifact ID 命名
│   ├── SnapKit-x1y2z3a4.zip
│   └── RxSwift-m1n2o3p4.zip
├── current/                      # 当前使用的 frameworks
│   ├── Alamofire/
│   │   └── Alamofire.xcframework
│   ├── SnapKit/
│   │   └── SnapKit.xcframework
│   └── RxSwift/
│       └── RxSwift.xcframework
└── Pods/                         # 预编译沙盒（仅预编译时使用）
```

## 📖 详细文档

- [配置指南](docs/配置指南.md) - 完整的配置选项说明和最佳实践
- [工作原理](docs/工作原理.md) - 插件内部实现原理和执行流程
- [API 文档](docs/API文档.md) - 所有公开接口的详细文档
- [示例项目](Example/) - 包含完整 Podfile 配置的示例

## 💡 最佳实践

### 1. 选择性预编译

**✅ 适合预编译**:
- 大型第三方库（Alamofire, RxSwift, AFNetworking）
- 稳定不变的库（版本长期不更新）
- 编译时间长的库

**❌ 不适合预编译**:
- 小型库（编译时间短，预编译收益低）
- 频繁修改的库（缓存命中率低）
- 项目内部模块（开发中，经常改动）
- 不支持 framework 的 Pod

### 2. 选择合适的 hash_factors

```ruby
# 开发环境：快速迭代，更高缓存命中率
config_binary_cache({
  artifact_hash_factors: [:source, :dependencies]
})

# CI 环境：平衡准确性和性能
config_binary_cache({
  artifact_hash_factors: [:source, :dependencies, :build_settings]
})

# 生产构建：最精确，确保二进制完全一致
config_binary_cache({
  artifact_hash_factors: [:source, :dependencies, :build_settings, :compiler_flags, :deployment_target]
})
```

### 3. 团队协作策略

**方案 A: 本地缓存（适合小团队）**
- 每个开发者本地执行 `pod binary prebuild`
- 将 `_Prebuild/` 加入 `.gitignore`

**方案 B: 共享缓存（适合大团队）**
- 在 CI 上执行 `pod binary prebuild`
- 将 `_Prebuild/artifacts/` 上传到共享存储（如 AWS S3、阿里云 OSS）
- 开发者从共享存储下载缓存

### 4. 性能优化建议

- 只预编译编译时间超过 30 秒的 Pods
- 使用 `--config=Release` 进行生产构建（更快的运行时性能）
- 定期清理缓存：`pod binary clean`
- 在 CI 中并行预编译多个 Pods

## 🔧 开发

### 本地开发

```bash
# 1. 克隆项目
git clone <your-repo>
cd cocoapods-binary-cache-mvp

# 2. 安装依赖
bundle install

# 3. 构建 gem
gem build cocoapods-binary-cache-mvp.gemspec

# 4. 本地安装测试
gem install cocoapods-binary-cache-mvp-0.1.0.gem

# 5. 在示例项目中测试
cd Example
pod binary prebuild
pod install
```

### 项目结构说明

所有核心代码都在 `lib/` 目录下：

- `cocoapods_plugin.rb` - CocoaPods 插件入口
- `cocoapods-binary-cache-mvp/`
  - `plugin.rb` - 注册插件和 DSL
  - `config/` - 配置管理
  - `cache/` - 缓存系统（Artifact、Manager、Validator）
  - `builder/` - Framework 构建器
  - `hooks/` - CocoaPods 钩子
  - `commands/` - CLI 命令

## 📄 许可证

MIT License

基于 [cocoapods-binary-cache](https://github.com/grab/cocoapods-binary-cache) 简化实现。
