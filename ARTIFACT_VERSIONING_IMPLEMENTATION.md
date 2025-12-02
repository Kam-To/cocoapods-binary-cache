# Artifact-Based Versioning Implementation Summary

## Overview

This implementation adds a new artifact-based versioning system to cocoapods-binary-cache, providing better support for multi-branch development workflows.

## Problem Solved

The original cache system compared `Podfile.lock` with `_Prebuild/Manifest.lock`, which caused issues when:
- Switching between git branches with different pod versions (e.g., Branch A: PodA 1.4.1, Branch B: PodA 1.4.2)
- Multiple developers working on different feature branches
- Same pod needed different build configurations

## Solution Design

### Core Concept

Each binary artifact is uniquely identified by: `PodName-Version-BuildHash`

Example: `AFNetworking-4.0.1-a1b2c3d4`

The build hash is generated from all factors that affect the binary output:
- Source (git URL, tag/branch)
- Dependencies and their versions
- Build settings and compiler flags
- Frameworks, libraries, and other linkage
- Platform and deployment targets
- Swift version, module settings, etc.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Plugin Configuration                     │
│  (artifact_versioning: { enabled: true })                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Pre-Install Hook (Validation)               │
│  - ArtifactResolver: Resolve required artifacts             │
│  - ArtifactsCacheValidator: Check availability              │
│  - ArtifactCacheManager: Fetch from local/remote            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Build (if cache miss)                      │
│  - Standard prebuild process                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Post-Build (Publish Artifacts)              │
│  - ArtifactCacheManager: Publish to local cache             │
│  - Create metadata.json with build info                      │
│  - Zip and upload to remote cache                            │
│  - Apply retention policy (LRU cleanup)                      │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Files

### New Files Created

1. **lib/cocoapods-binary-cache/cache/artifact_version.rb**
   - Generates unique artifact IDs based on build factors
   - Computes SHA256 hash from all relevant build settings

2. **lib/cocoapods-binary-cache/cache/artifact.rb**
   - Artifact model class
   - Generates metadata for each artifact

3. **lib/cocoapods-binary-cache/cache/artifact_resolver.rb**
   - Resolves artifacts from Podfile.lock
   - Loads pod specifications

4. **lib/cocoapods-binary-cache/cache/artifact_cache_manager.rb**
   - Manages local and remote artifact cache
   - Handles fetch, publish, and cleanup operations
   - Creates symlinks to current artifacts

5. **lib/cocoapods-binary-cache/cache/validator_artifacts.rb**
   - Validates cache using artifact system
   - Replaces legacy lockfile comparison

6. **docs/artifact_versioning.md**
   - Complete user documentation
   - Configuration examples and workflows

### Modified Files

1. **lib/command/config.rb**
   - Added `artifact_versioning_enabled?`
   - Added `artifact_versioning_config`
   - Added `local_artifact_retention`
   - Updated `applicable_dsl_config` list

2. **lib/cocoapods-binary-cache/cache/all.rb**
   - Required all new artifact-related modules

3. **lib/cocoapods-binary-cache/hooks/pre_install.rb**
   - Split `validate_cache` into `validate_cache_legacy` and `validate_cache_with_artifacts`
   - Conditional logic based on `artifact_versioning_enabled?`

4. **lib/command/executor/prebuilder.rb**
   - Split `sync_cache` into `sync_cache_legacy` and `sync_cache_with_artifacts`
   - Publishes artifacts after build

5. **lib/cocoapods-binary-cache/pod-binary/helper/prebuild_sandbox.rb**
   - Updated `generate_framework_path` to use `current/` directory in artifact mode
   - Updated `framework_folder_path_for_target_name` for artifact mode

6. **PodBinaryCacheExample/Podfile**
   - Added example artifact_versioning configuration (commented out)

## Cache Structure

### Local Cache (Artifact Mode)

```
~/.cocoapods-binary-cache/
└── artifacts/
    ├── AFNetworking-4.0.1-a1b2c3d4/
    │   ├── AFNetworking.framework
    │   └── metadata.json
    ├── AFNetworking-4.0.2-e5f6g7h8/
    │   └── ...
    └── ...

_Prebuild/
└── current/                    # Symlinks to active artifacts
    ├── AFNetworking.framework -> ~/.cocoapods-binary-cache/artifacts/AFNetworking-4.0.1-a1b2c3d4/AFNetworking.framework
    └── ...
```

### Remote Cache (Artifact Mode)

```
cache-repo/
└── artifacts/
    ├── AFNetworking-4.0.1-a1b2c3d4.zip
    ├── AFNetworking-4.0.1-a1b2c3d4.json
    ├── AFNetworking-4.0.2-e5f6g7h8.zip
    ├── AFNetworking-4.0.2-e5f6g7h8.json
    └── ...
```

## Configuration

### Basic Configuration

```ruby
config_cocoapods_binary_cache(
  cache_repo: {
    "default" => {
      "local" => "~/.cocoapods-binary-cache"
    }
  },

  artifact_versioning: {
    enabled: true
  }
)
```

### Advanced Configuration

```ruby
config_cocoapods_binary_cache(
  # ... standard config ...

  artifact_versioning: {
    enabled: true,
    hash_factors: [
      :source,
      :dependencies,
      :build_settings,
      :compiler_flags,
      :deployment_target
    ]
  },

  local_artifact_retention: {
    strategy: :lru,
    max_count: 50,
    max_size_mb: 5000
  }
)
```

## Backward Compatibility

- Legacy cache system remains fully functional
- Set `artifact_versioning: { enabled: false }` or omit to use legacy mode
- Both systems can coexist during migration
- No breaking changes to existing configurations

## Key Benefits

✅ **Branch-Safe**: Each branch's pod versions get separate artifacts
✅ **Team Sharing**: Share artifacts across all branches via remote cache
✅ **Config Isolation**: Different build configs produce different artifacts
✅ **Long-Term Stable**: Artifacts persist indefinitely, reusable across time
✅ **Efficient Storage**: LRU cleanup prevents disk bloat
✅ **Zero Rebuild**: Switching back to a branch reuses cached artifacts instantly

## Testing

To test the implementation:

1. Enable artifact versioning in Podfile
2. Run `pod install` on branch A
3. Switch to branch B with different pod versions
4. Run `pod install` on branch B
5. Switch back to branch A
6. Run `pod install` - should hit local cache instantly

## Next Steps

Potential enhancements:
- Add more hash strategies (content-based, time-based)
- Implement artifact garbage collection commands
- Add artifact inspection/debugging tools
- Support for artifact metadata queries
- Cache statistics and analytics
