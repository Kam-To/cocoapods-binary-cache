# Artifact-Based Binary Cache Configuration Example

## Overview

This document demonstrates how to configure cocoapods-binary-cache with the new artifact-based versioning system. This approach provides better support for multi-branch development workflows.

## Problem Solved

Traditional cache systems based on `Podfile.lock` comparison can fail when:
- Switching between git branches with different pod versions
- Multiple developers working on different feature branches
- Same pod version needs different build configurations

## How It Works

Artifact-based versioning creates a unique identifier for each binary based on:
- Pod name and version (e.g., `AFNetworking-4.0.1`)
- Source information (git URL, tag/branch)
- Build settings and compiler flags
- Dependencies and their versions
- Platform and deployment targets

Format: `PodName-Version-BuildHash` (e.g., `AFNetworking-4.0.1-a1b2c3d4`)

## Configuration

### Basic Configuration

```ruby
# Podfile
plugin 'cocoapods-binary-cache'

config_cocoapods_binary_cache(
  cache_repo: {
    "default" => {
      "remote" => "git@github.com:your-org/binary-cache.git",
      "local" => "~/.cocoapods-binary-cache"
    }
  },

  # Enable artifact-based versioning
  artifact_versioning: {
    enabled: true
  }
)

target 'YourApp' do
  pod 'AFNetworking', :binary => true
  pod 'Alamofire', :binary => true
end
```

### Advanced Configuration

```ruby
config_cocoapods_binary_cache(
  cache_repo: {
    "default" => {
      "remote" => "git@github.com:your-org/binary-cache.git",
      "local" => "~/.cocoapods-binary-cache"
    }
  },

  # Artifact versioning configuration
  artifact_versioning: {
    enabled: true,

    # Control which factors are included in the build hash
    # Default: [:source, :dependencies, :build_settings, :compiler_flags, :deployment_target]
    hash_factors: [
      :source,              # Git URL, tag, branch
      :dependencies,        # All pod dependencies
      :build_settings,      # Custom build settings
      :compiler_flags,      # Compiler flags
      :deployment_target,   # iOS/macOS deployment targets
      :frameworks,          # Linked frameworks
      :libraries,           # Linked libraries
      :swift_version        # Swift version
    ]
  },

  # Local artifact retention policy
  local_artifact_retention: {
    strategy: :lru,        # Least Recently Used cleanup strategy
    max_count: 50,         # Keep maximum 50 artifacts
    max_size_mb: 5000      # Maximum 5GB of disk space
  },

  # Other standard configurations
  prebuild_config: "Release",
  excluded_pods: ["PodA", "PodB"],
  dev_pods_enabled: true
)
```

## Cache Structure

### Local Cache Structure

```
~/.cocoapods-binary-cache/
├── artifacts/                              # All binary artifacts
│   ├── AFNetworking-4.0.1-a1b2c3d4/
│   │   ├── AFNetworking.framework
│   │   └── metadata.json
│   ├── AFNetworking-4.0.2-e5f6g7h8/
│   │   ├── AFNetworking.framework
│   │   └── metadata.json
│   └── Alamofire-5.4.0-12345678/
│       ├── Alamofire.framework
│       └── metadata.json
└── ...

_Prebuild/
└── current/                                # Symlinks to currently used artifacts
    ├── AFNetworking.framework -> ~/.cocoapods-binary-cache/artifacts/AFNetworking-4.0.1-a1b2c3d4/AFNetworking.framework
    └── Alamofire.framework -> ~/.cocoapods-binary-cache/artifacts/Alamofire-5.4.0-12345678/Alamofire.framework
```

### Remote Cache Structure

```
binary-cache-repo/
└── artifacts/
    ├── AFNetworking-4.0.1-a1b2c3d4.zip
    ├── AFNetworking-4.0.1-a1b2c3d4.json    # metadata
    ├── AFNetworking-4.0.2-e5f6g7h8.zip
    ├── AFNetworking-4.0.2-e5f6g7h8.json
    ├── Alamofire-5.4.0-12345678.zip
    └── Alamofire-5.4.0-12345678.json
```

## Workflow Examples

### Scenario 1: Branch Switching

```bash
# Branch A: AFNetworking 4.0.1
git checkout feature-A
pod install
# Cache: AFNetworking-4.0.1-a1b2c3d4 [HIT or MISS, then cache]

# Branch B: AFNetworking 4.0.2
git checkout feature-B
pod install
# Cache: AFNetworking-4.0.2-e5f6g7h8 [HIT or MISS, then cache]

# Back to Branch A
git checkout feature-A
pod install
# Cache: AFNetworking-4.0.1-a1b2c3d4 [LOCAL HIT - instant!]
```

### Scenario 2: Team Collaboration

```bash
# Developer A builds AFNetworking-4.0.1-a1b2c3d4
Developer-A$ pod binary prebuild --push

# Developer B (on different branch, same pod version)
Developer-B$ pod install
# Cache: AFNetworking-4.0.1-a1b2c3d4 [REMOTE HIT - downloads from cache]
```

### Scenario 3: Different Build Configurations

```ruby
# Debug configuration
config_cocoapods_binary_cache(
  prebuild_config: "Debug",
  artifact_versioning: { enabled: true }
)
# Produces: AFNetworking-4.0.1-debug123

# Release configuration
config_cocoapods_binary_cache(
  prebuild_config: "Release",
  artifact_versioning: { enabled: true }
)
# Produces: AFNetworking-4.0.1-release456
```

## Migration from Legacy Cache

The plugin supports both legacy and artifact-based caching simultaneously:

```ruby
config_cocoapods_binary_cache(
  # ... other configs ...

  # Set to false or omit to use legacy caching
  artifact_versioning: {
    enabled: false  # or simply don't include this section
  }
)
```

To migrate:

1. **Enable artifact versioning** in your Podfile configuration
2. Run `pod install` - it will start using the new artifact system
3. Old cache remains untouched in `_Prebuild/GeneratedFrameworks/`
4. New artifacts are stored in `~/.cocoapods-binary-cache/artifacts/`

## Benefits

✅ **Branch-Safe**: Each pod version gets its own artifact, safe branch switching
✅ **Team-Wide Sharing**: Share artifacts across all branches via remote cache
✅ **Build Configuration Isolation**: Different configs produce different artifacts
✅ **Long-Term Stable**: Artifacts persist and can be reused indefinitely
✅ **Efficient Storage**: LRU cleanup prevents disk bloat

## Troubleshooting

### Cache Not Found After Enabling Artifact Versioning

This is expected on first run. The plugin needs to rebuild and cache artifacts:

```bash
pod binary prebuild --push
```

### High Disk Usage

Adjust retention policy:

```ruby
local_artifact_retention: {
  strategy: :lru,
  max_count: 20,        # Reduce max artifacts
  max_size_mb: 2000     # Reduce max size
}
```

### Different Build Hash for Same Configuration

Check that all developers use identical:
- Xcode version
- Swift version
- Build settings in `validate_prebuilt_settings`

## Commands

```bash
# Prebuild and push to cache
pod binary prebuild --push

# Install with artifact caching
pod install

# Clean local cache
rm -rf ~/.cocoapods-binary-cache/artifacts/*
```
