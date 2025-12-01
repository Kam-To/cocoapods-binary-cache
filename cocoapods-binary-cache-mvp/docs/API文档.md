# API 文档

## 模块概览

```
CocoapodsBinaryCacheMVP
├── Config                    # 配置管理（单例）
├── Artifact                  # 制品数据结构
├── CacheManager             # 缓存管理器
├── CacheValidator           # 缓存验证器
├── FrameworkBuilder         # Framework 构建器
└── PreInstallHook           # Pre-install 钩子
```

---

## CocoapodsBinaryCacheMVP::Config

配置管理器（单例模式）

### 类方法

#### `.instance`
获取单例实例

**返回值**: `Config` 实例

**示例**:
```ruby
config = CocoapodsBinaryCacheMVP::Config.instance
puts config.cache_path
```

### 实例方法

#### `#update(options)`
更新配置

**参数**:
- `options` (Hash): 配置选项

**可用选项**:
- `:cache_path` (String): 缓存根目录
- `:prebuild_config` (String): 预编译配置（Debug/Release）
- `:artifact_hash_factors` (Array<Symbol>): 哈希计算因子
- `:validate_prebuilt_settings` (Boolean): 是否验证预编译设置

**示例**:
```ruby
config.update({
  cache_path: "_Prebuild",
  prebuild_config: "Debug",
  artifact_hash_factors: [:source, :dependencies]
})
```

#### `#cache_path`
获取缓存根目录

**返回值**: `String`

**默认值**: `"_Prebuild"`

#### `#artifacts_path`
获取 artifacts 存储目录

**返回值**: `String`

**计算**: `#{cache_path}/artifacts`

#### `#current_frameworks_path`
获取当前 frameworks 目录

**返回值**: `String`

**计算**: `#{cache_path}/current`

#### `#prebuild_sandbox_path`
获取预编译沙盒路径

**返回值**: `String`

**计算**: `#{cache_path}/Pods`

#### `#prebuild_config`
获取预编译配置名称

**返回值**: `String`

**默认值**: `"Debug"`

#### `#artifact_hash_factors`
获取 Artifact 哈希计算因子

**返回值**: `Array<Symbol>`

**默认值**: `[:source, :dependencies, :build_settings, :compiler_flags, :deployment_target]`

#### `#validate_prebuilt_settings`
是否验证预编译设置

**返回值**: `Boolean`

**默认值**: `false`

#### `#prebuild_job`
是否为预编译任务

**返回值**: `Boolean`

**默认值**: `false`

#### `#prebuild_job=(value)`
设置预编译任务标记

**参数**:
- `value` (Boolean)

#### `#validate!`
验证配置的有效性

**返回值**: `Boolean`

**异常**: 配置无效时抛出异常

---

## CocoapodsBinaryCacheMVP::Artifact

Artifact（制品）数据结构

### 初始化

#### `new(name, version, hash_data)`

**参数**:
- `name` (String): Pod 名称
- `version` (String): Pod 版本
- `hash_data` (Hash): 用于计算哈希的数据

**示例**:
```ruby
artifact = CocoapodsBinaryCacheMVP::Artifact.new(
  'Alamofire',
  '5.6.0',
  {
    source: 'f1b72917a6b3f4e6d4e5c6d7e8f9a0b1',
    dependencies: 'RxSwift-6.5.0',
    build_settings: 'DEBUG=1'
  }
)
```

### 实例方法

#### `#artifact_id`
获取 Artifact ID（唯一标识符）

**返回值**: `String`

**格式**: `{name}-{hash前16位}`

**示例**: `"Alamofire-a1b2c3d4e5f6g7h8"`

#### `#calculate_artifact_id`
计算 Artifact ID

**返回值**: `String`

**算法**:
```ruby
# 1. 提取配置的 hash_factors 对应的数据
factors = CocoapodsBinaryCacheMVP.config.artifact_hash_factors
hash_components = factors.map { |factor| @hash_data[factor] }.compact

# 2. 拼接并计算 SHA256
hash_string = hash_components.join('-')
hash_value = Digest::SHA256.hexdigest(hash_string)[0..15]

# 3. 生成 Artifact ID
"#{@name}-#{hash_value}"
```

---

## CocoapodsBinaryCacheMVP::CacheManager

缓存管理器

### 初始化

#### `new(config = nil)`

**参数**:
- `config` (Config, optional): 配置实例，默认使用全局配置

### 实例方法

#### `#publish(artifact, framework_path)`
发布 Artifact 到缓存

**参数**:
- `artifact` (Artifact): Artifact 实例
- `framework_path` (String): Framework 文件路径

**返回值**: `Boolean` - 成功返回 true

**示例**:
```ruby
manager = CocoapodsBinaryCacheMVP::CacheManager.new

artifact = CocoapodsBinaryCacheMVP::Artifact.new('Alamofire', '5.6.0', hash_data)
framework_path = '_Prebuild/current/Alamofire/Alamofire.xcframework'

manager.publish(artifact, framework_path)
```

**流程**:
1. 验证 framework 文件存在
2. 创建 zip 文件
3. 保存到 `artifacts/{artifact_id}.zip`

#### `#fetch(artifact, dest_path)`
从缓存获取 Artifact

**参数**:
- `artifact` (Artifact): Artifact 实例
- `dest_path` (String): 解压目标路径

**返回值**: `Boolean` - 成功返回 true，缓存不存在返回 false

**示例**:
```ruby
manager = CocoapodsBinaryCacheMVP::CacheManager.new

artifact = CocoapodsBinaryCacheMVP::Artifact.new('Alamofire', '5.6.0', hash_data)
dest_path = '_Prebuild/current/Alamofire'

if manager.fetch(artifact, dest_path)
  puts "缓存命中"
else
  puts "缓存缺失"
end
```

**流程**:
1. 查找 `artifacts/{artifact_id}.zip`
2. 解压到 dest_path
3. 返回结果

#### `#exists?(artifact)`
检查 Artifact 缓存是否存在

**参数**:
- `artifact` (Artifact): Artifact 实例

**返回值**: `Boolean`

**示例**:
```ruby
if manager.exists?(artifact)
  puts "缓存存在"
end
```

#### `#cleanup(max_count: 100, max_size_mb: 5000)`
清理旧的缓存文件

**参数**:
- `max_count` (Integer, optional): 最大保留文件数，默认 100
- `max_size_mb` (Integer, optional): 最大缓存大小（MB），默认 5000

**返回值**: `void`

**示例**:
```ruby
# 保留最新 50 个文件，总大小不超过 2GB
manager.cleanup(max_count: 50, max_size_mb: 2000)
```

**策略**: 按修改时间排序，删除最旧的文件

---

## CocoapodsBinaryCacheMVP::CacheValidator

缓存验证器

### 初始化

#### `new(lockfile, prebuilt_pods)`

**参数**:
- `lockfile` (Pod::Lockfile): Podfile.lock 实例
- `prebuilt_pods` (Array<String>): 预编译 Pod 名称列表

**示例**:
```ruby
lockfile = Pod::Lockfile.from_file('Podfile.lock')
prebuilt_pods = ['Alamofire', 'SnapKit', 'RxSwift']

validator = CocoapodsBinaryCacheMVP::CacheValidator.new(lockfile, prebuilt_pods)
```

### 实例方法

#### `#validate`
执行缓存验证

**返回值**: `Hash` - 验证结果
```ruby
{
  hits: Set<String>,        # 缓存命中的 Pod 名称
  misses: Set<String>,      # 缓存缺失的 Pod 名称
  artifacts: Hash           # Pod 名称 -> Artifact 映射
}
```

**示例**:
```ruby
result = validator.validate

result[:hits].each do |pod_name|
  artifact = result[:artifacts][pod_name]
  puts "✅ #{pod_name} (#{artifact.artifact_id})"
end

result[:misses].each do |pod_name|
  artifact = result[:artifacts][pod_name]
  puts "❌ #{pod_name} (#{artifact.artifact_id})"
end
```

#### `#print_summary`
打印验证结果摘要

**返回值**: `void`

**示例**:
```ruby
validator.validate
validator.print_summary
```

**输出**:
```
缓存验证结果:
✅ 命中缓存 (2):
  - Alamofire (Alamofire-a1b2c3d4e5f6g7h8)
  - SnapKit (SnapKit-x1y2z3a4b5c6d7e8)

❌ 缓存缺失 (1):
  - RxSwift (RxSwift-m1n2o3p4q5r6s7t8)
```

#### `#create_artifact(pod_name)`
为指定 Pod 创建 Artifact

**参数**:
- `pod_name` (String): Pod 名称

**返回值**: `Artifact` 或 `nil`

**示例**:
```ruby
artifact = validator.create_artifact('Alamofire')
puts artifact.artifact_id
```

### 私有方法

#### `#collect_hash_data(pod_name)`
收集用于哈希计算的数据

**参数**:
- `pod_name` (String): Pod 名称

**返回值**: `Hash`

**收集的数据**:
- `:source` - Pod checksum（来自 Podfile.lock 的 SPEC CHECKSUMS）
- `:dependencies` - 依赖的 Pods 及版本
- `:build_settings` - 构建设置
- `:compiler_flags` - 编译器标志
- `:deployment_target` - 部署目标版本

---

## CocoapodsBinaryCacheMVP::FrameworkBuilder

Framework 构建器

### 初始化

#### `new(sandbox_path)`

**参数**:
- `sandbox_path` (String): 沙盒路径

**示例**:
```ruby
builder = CocoapodsBinaryCacheMVP::FrameworkBuilder.new('_Prebuild/Pods')
```

### 实例方法

#### `#build(pod_name, pod_target)`
构建指定 Pod 的 Framework

**参数**:
- `pod_name` (String): Pod 名称
- `pod_target` (Pod::PodTarget): Pod target 实例

**返回值**: `String` - Framework 输出路径

**示例**:
```ruby
# 需要先获取 installer 和 pod_target
installer = Pod::Installer.new(
  Pod::Config.instance.sandbox,
  podfile,
  lockfile
)
installer.resolve_dependencies

pod_target = installer.pod_targets.find { |t| t.pod_name == 'Alamofire' }

builder = CocoapodsBinaryCacheMVP::FrameworkBuilder.new('_Prebuild/Pods')
framework_path = builder.build('Alamofire', pod_target)

puts "Framework 输出: #{framework_path}"
```

**构建流程**:
1. 为 iOS 模拟器构建
2. 为 iOS 真机构建
3. 合并为 xcframework（或 framework）
4. 返回输出路径

#### `#build_for_sdk(pod_name, sdk)`
为特定 SDK 构建 Framework

**参数**:
- `pod_name` (String): Pod 名称
- `sdk` (String): SDK 名称（`"iphoneos"` 或 `"iphonesimulator"`）

**返回值**: `String` - Framework 路径

**示例**:
```ruby
# 仅为模拟器构建
simulator_framework = builder.build_for_sdk('Alamofire', 'iphonesimulator')
```

---

## CocoapodsBinaryCacheMVP::PreInstallHook

Pre-install 钩子

### 初始化

#### `new(installer_context)`

**参数**:
- `installer_context` (Pod::Installer::InstallationOptions::InstallerContext): 安装上下文

**注意**: 通常不需要手动创建，由插件自动调用

### 实例方法

#### `#run`
执行钩子逻辑

**返回值**: `void`

**流程**:
1. 检测预编译 Pods（`:binary => true`）
2. 验证缓存
3. 如果是预编译任务，执行预编译

**示例**:
```ruby
# 在插件中自动调用
Pod::HooksManager.register('cocoapods-binary-cache-mvp', :pre_install) do |context|
  hook = CocoapodsBinaryCacheMVP::PreInstallHook.new(context)
  hook.run
end
```

---

## Podfile DSL

### `config_binary_cache(options)`

配置插件

**参数**:
- `options` (Hash): 配置选项

**可用选项**: 见 [Config#update](#update-options)

**示例**:
```ruby
plugin 'cocoapods-binary-cache-mvp'

config_binary_cache({
  cache_path: "_Prebuild",
  prebuild_config: "Debug",
  artifact_hash_factors: [:source, :dependencies]
})
```

### Pod 选项: `:binary`

标记 Pod 为预编译

**类型**: `Boolean`

**示例**:
```ruby
pod 'Alamofire', :binary => true
pod 'SnapKit', '~> 5.0', :binary => true
```

---

## 命令行接口

### `pod binary prebuild`

执行预编译

**选项**:
- `--config=CONFIG` - 指定构建配置（Debug/Release）
- `--clean` - 预编译前清理缓存

**示例**:
```bash
# 使用 Debug 配置预编译
pod binary prebuild --config=Debug

# 清理缓存并预编译
pod binary prebuild --clean

# 使用 Release 配置
pod binary prebuild --config=Release
```

### `pod binary clean`

清理所有缓存

**示例**:
```bash
pod binary clean
```

---

## 使用示例

### 完整工作流

```ruby
# 1. Podfile 配置
plugin 'cocoapods-binary-cache-mvp'

config_binary_cache({
  cache_path: "_Prebuild",
  prebuild_config: "Debug",
  artifact_hash_factors: [:source, :dependencies]
})

target 'MyApp' do
  pod 'Alamofire', :binary => true
  pod 'SnapKit', :binary => true
  pod 'RxSwift', :binary => true
end

# 2. 在 CI 或本地执行预编译
# $ pod binary prebuild

# 3. 开发时正常执行 pod install
# $ pod install
# （自动使用缓存）

# 4. 清理缓存（可选）
# $ pod binary clean
```

### 编程方式使用

```ruby
require 'cocoapods-binary-cache-mvp'

# 1. 配置
config = CocoapodsBinaryCacheMVP::Config.instance
config.update({
  cache_path: "_Prebuild",
  prebuild_config: "Debug"
})

# 2. 创建 Artifact
hash_data = {
  source: 'abc123...',
  dependencies: 'RxSwift-6.5.0'
}
artifact = CocoapodsBinaryCacheMVP::Artifact.new('Alamofire', '5.6.0', hash_data)

# 3. 使用缓存管理器
manager = CocoapodsBinaryCacheMVP::CacheManager.new

# 发布缓存
if File.exist?('Alamofire.xcframework')
  manager.publish(artifact, 'Alamofire.xcframework')
end

# 获取缓存
if manager.fetch(artifact, './output')
  puts "缓存命中"
else
  puts "缓存缺失"
end

# 清理旧缓存
manager.cleanup(max_count: 50)
```
