# 示例项目

本目录包含演示如何使用 `cocoapods-binary-cache-mvp` 插件的示例配置。

## 目录结构

```
Example/
├── Podfile              # 示例 Podfile 配置
├── README.md            # 本文件
└── .gitignore           # Git 忽略配置
```

## 快速开始

### 1. 安装插件

首先，安装 cocoapods-binary-cache-mvp 插件：

```bash
# 从本地安装（开发时）
cd ..
gem build cocoapods-binary-cache-mvp.gemspec
gem install cocoapods-binary-cache-mvp-0.1.0.gem

# 或者从 Gemfile 安装
# gem 'cocoapods-binary-cache-mvp', :path => '../'
```

### 2. 查看示例 Podfile

查看 [Podfile](./Podfile) 了解详细配置：

```ruby
plugin 'cocoapods-binary-cache-mvp'

config_binary_cache({
  cache_path: "_Prebuild",
  prebuild_config: "Debug",
  artifact_hash_factors: [:source, :dependencies]
})

target 'ExampleApp' do
  # 预编译的 Pods（标记 :binary => true）
  pod 'Alamofire', '~> 5.6', :binary => true
  pod 'RxSwift', '~> 6.5', :binary => true

  # 普通 Pods（不使用缓存）
  pod 'SwiftyJSON'
end
```

### 3. 执行预编译

```bash
# 预编译所有标记为 :binary => true 的 Pods
pod binary prebuild

# 使用 Release 配置
pod binary prebuild --config=Release

# 清理缓存后重新编译
pod binary prebuild --clean
```

预编译过程：
1. 分析 Podfile.lock，计算每个 Pod 的 Artifact ID
2. 检查缓存是否存在
3. 编译缺失的 Pods
4. 将编译结果打包为 .zip 并存储到 `_Prebuild/artifacts/`

### 4. 日常开发

日常开发时，直接执行 `pod install`：

```bash
pod install
```

插件会自动：
- 检查缓存状态
- 使用已缓存的二进制框架
- 显著减少编译时间

### 5. 清理缓存

如果需要清理所有缓存：

```bash
pod binary clean
```

## 缓存目录结构

执行预编译后，会生成以下目录结构：

```
_Prebuild/
├── artifacts/                              # 压缩的缓存文件
│   ├── Alamofire-a1b2c3d4e5f6g7h8.zip     # Artifact ID 作为文件名
│   ├── RxSwift-x1y2z3a4b5c6d7e8.zip
│   ├── RxCocoa-m1n2o3p4q5r6s7t8.zip
│   └── SnapKit-i1j2k3l4m5n6o7p8.zip
├── current/                                # 当前使用的 frameworks
│   ├── Alamofire/
│   │   └── Alamofire.xcframework
│   ├── RxSwift/
│   │   └── RxSwift.xcframework
│   ├── RxCocoa/
│   │   └── RxCocoa.xcframework
│   └── SnapKit/
│       └── SnapKit.xcframework
└── Pods/                                   # 预编译沙盒（临时）
```

## 验证缓存

执行 `pod install` 时会看到缓存验证结果：

```
🚀 CocoaPods Binary Cache MVP
检测到 4 个预编译 Pods: Alamofire, RxSwift, RxCocoa, SnapKit

缓存验证结果:
✅ 命中缓存 (4):
  - Alamofire (Alamofire-a1b2c3d4e5f6g7h8)
  - RxSwift (RxSwift-x1y2z3a4b5c6d7e8)
  - RxCocoa (RxCocoa-m1n2o3p4q5r6s7t8)
  - SnapKit (SnapKit-i1j2k3l4m5n6o7p8)

❌ 缓存缺失 (0):
```

## 常见场景

### 场景 1: 添加新的预编译 Pod

1. 在 Podfile 中添加 Pod 并标记 `:binary => true`
   ```ruby
   pod 'Kingfisher', '~> 7.0', :binary => true
   ```

2. 执行预编译
   ```bash
   pod binary prebuild
   ```

3. 正常使用
   ```bash
   pod install
   ```

### 场景 2: 更新 Pod 版本

1. 修改 Podfile 中的版本号
   ```ruby
   pod 'Alamofire', '~> 5.7', :binary => true  # 从 5.6 更新到 5.7
   ```

2. 执行预编译（插件会检测版本变化）
   ```bash
   pod binary prebuild
   ```

3. 正常使用
   ```bash
   pod install
   ```

### 场景 3: 切换构建配置

开发时使用 Debug，打包时使用 Release：

```bash
# 开发
pod binary prebuild --config=Debug
pod install

# 打包
pod binary prebuild --config=Release
pod install
```

**注意**: 不同配置会生成不同的 Artifact ID，缓存互不影响。

### 场景 4: 团队协作

**方案 A: 本地缓存（推荐新手）**
- 每个开发者本地执行 `pod binary prebuild`
- 缓存目录加入 `.gitignore`

**方案 B: 共享缓存（推荐团队）**
- 在 CI 上执行 `pod binary prebuild`
- 将 `_Prebuild/artifacts/` 上传到共享存储（如 S3）
- 开发者从共享存储下载缓存

## 性能对比

以本示例 Podfile 为例（4 个预编译 Pod）：

| 场景 | 首次编译 | 使用缓存 | 节省时间 |
|------|---------|---------|---------|
| 无插件 | ~5 分钟 | ~5 分钟 | 0% |
| 使用插件 | ~5 分钟（预编译）| ~30 秒 | ~90% |

**注意**: 实际效果取决于预编译 Pods 的数量和复杂度。

## 故障排查

### 问题 1: `Unknown command: 'binary'`

**原因**: 插件未安装或未正确加载

**解决**:
```bash
gem install cocoapods-binary-cache-mvp
```

### 问题 2: 缓存命中但编译失败

**原因**: Artifact ID 相同但二进制不兼容（hash_factors 太少）

**解决**:
```ruby
# 增加 hash_factors
config_binary_cache({
  artifact_hash_factors: [:source, :dependencies, :build_settings]
})
```

然后重新预编译：
```bash
pod binary clean
pod binary prebuild
```

### 问题 3: 预编译失败

**原因**: 某些 Pod 不支持编译为 framework

**解决**: 不要为这些 Pod 添加 `:binary => true` 标记

### 问题 4: 缓存占用空间过大

**解决**: 定期清理缓存
```bash
pod binary clean
```

## 更多文档

- [配置指南](../docs/配置指南.md) - 详细的配置选项说明
- [工作原理](../docs/工作原理.md) - 插件内部实现原理
- [API 文档](../docs/API文档.md) - 编程接口文档
- [主 README](../README.md) - 插件概览

## 反馈与支持

如有问题或建议，请提交 Issue。
