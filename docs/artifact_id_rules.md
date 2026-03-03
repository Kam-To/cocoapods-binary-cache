# Artifact ID Rules

This document defines the frozen inputs used to generate `artifact_id`.

`artifact_id` format:

`PodName-PodVersion-BuildHash`

`BuildHash` is computed from a normalized JSON payload. Any change to the
payload keys listed below is a cache-identity change and should be treated as a
breaking change to cache behavior.

## Standard Pods

For pods resolved from specs repos, git sources, tags, branches, or other
non-`:path` sources, the hash inputs are:

- `version`
- `source`
- `dev_pod_source_hash`
- `source_files`
- `public_header_files`
- `private_header_files`
- `vendored_frameworks`
- `vendored_libraries`
- `dependencies`
- `resolved_dependencies`
- `compiler_flags`
- `frameworks`
- `weak_frameworks`
- `libraries`
- `xcconfig`
- `pod_target_xcconfig`
- `user_target_xcconfig`
- `build_settings`
- `platforms`
- `deployment_target`
- `requires_arc`
- `module_name`
- `module_map`
- `header_dir`
- `header_mappings_dir`
- `swift_version`
- `resources`
- `resource_bundles`
- `preserve_paths`
- `prepare_command`
- `script_phases`

Normalization rules:

- `source` drops `:commit` when `:tag` or `:branch` is present.
- `resolved_dependencies` is the sorted list of direct dependency names paired
  with resolved versions.
- `build_settings` is normalized into a hash with sorted keys.

## Dev Pods (`:path`)

For dev pods declared with `:path`, the hash inputs are intentionally narrower:

- `version`
- `source`
- `dev_pod_source_hash`
- `resolved_dependencies`
- `build_settings`

Normalization rules:

- `source` is forced to `{ dev_pod: true }` to avoid unstable differences in
  podspec source representations between install stages.
- `dev_pod_source_hash` is the content hash of the local pod directory.
- The content hash ignores generated directories and local noise:
  `_Prebuild`, `_Prebuilt`, `Pods`, `.DS_Store`.

## Change Policy

If you change this rule set:

1. Update `ArtifactVersion::STANDARD_FACTOR_KEYS` and/or
   `ArtifactVersion::DEV_POD_FACTOR_KEYS`.
2. Update the tests under `spec/cocoapods-binary-cache/cache` and
   `spec/cocoapods-binary-cache/helper`.
3. Treat the change as a cache-identity breaking change and document it in the
   release notes.
