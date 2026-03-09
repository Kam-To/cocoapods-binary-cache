#!/bin/sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/PodBinaryCacheExample"
PODFILE="$EXAMPLE_DIR/Podfile"
AMR_FILE="$ROOT_DIR/local_pod/AmrCodec/AmrCodec/amrFileCodec.m"
RUBY_BUNDLE="${BUNDLE_BIN:-bundle}"

cleanup() {
  git -C "$ROOT_DIR" checkout -- "$PODFILE" >/dev/null 2>&1 || true
  git -C "$ROOT_DIR" checkout -- "$EXAMPLE_DIR/Podfile.lock" >/dev/null 2>&1 || true
  git -C "$ROOT_DIR" checkout -- "$AMR_FILE" >/dev/null 2>&1 || true
}

extract_key() {
  pod_name="$1"
  log_file="$2"
  grep -Eo "${pod_name}-[0-9A-Za-z._-]+-[0-9a-f]{8}" "$log_file" | tail -n 1
}

run_prebuild() {
  log_file="$1"
  (
    cd "$EXAMPLE_DIR"
    "$RUBY_BUNDLE" exec pod binary prebuild
  ) >"$log_file" 2>&1
}

assert_non_empty() {
  value="$1"
  message="$2"
  if [ -z "$value" ]; then
    echo "Assertion failed: $message" >&2
    exit 1
  fi
}

assert_equal() {
  expected="$1"
  actual="$2"
  message="$3"
  if [ "$expected" != "$actual" ]; then
    echo "Assertion failed: $message" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

assert_not_equal() {
  left="$1"
  right="$2"
  message="$3"
  if [ "$left" = "$right" ]; then
    echo "Assertion failed: $message" >&2
    echo "Both values: $left" >&2
    exit 1
  fi
}

prepare_logs() {
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"; cleanup' EXIT INT TERM
}

set_afnetworking_version_mode() {
  python3 - "$PODFILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace("  pod 'AFNetworking', :git => 'https://git-opd.nie.netease.com/gl-ios/afnetworking.git', :tag => '2.7.2', :binary => true\n", "#  pod 'AFNetworking', :git => 'https://git-opd.nie.netease.com/gl-ios/afnetworking.git', :tag => '2.7.2', :binary => true\n")
text = text.replace("#  pod 'AFNetworking', '3.2.1', :binary => true\n", "  pod 'AFNetworking', '3.2.1', :binary => true\n")
path.write_text(text)
PY
}

set_afnetworking_git_mode() {
  python3 - "$PODFILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace("  pod 'AFNetworking', '3.2.1', :binary => true\n", "#  pod 'AFNetworking', '3.2.1', :binary => true\n")
text = text.replace("#  pod 'AFNetworking', :git => 'https://git-opd.nie.netease.com/gl-ios/afnetworking.git', :tag => '2.7.2', :binary => true\n", "  pod 'AFNetworking', :git => 'https://git-opd.nie.netease.com/gl-ios/afnetworking.git', :tag => '2.7.2', :binary => true\n")
path.write_text(text)
PY
}

mutate_amr_source() {
  python3 - "$AMR_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
marker = "// integration-test mutation\n"
if marker in text:
    text = text.replace(marker, "// integration-test mutation v2\n", 1)
else:
    text += ("\n" if not text.endswith("\n") else "") + marker
path.write_text(text)
PY
}

test_afnetworking_switch() {
  echo "Running AFNetworking switch regression"
  set_afnetworking_version_mode
  run_prebuild "$TMP_DIR/af_v1.log"
  first_key="$(extract_key "AFNetworking" "$TMP_DIR/af_v1.log")"
  assert_non_empty "$first_key" "AFNetworking key missing in version mode"

  set_afnetworking_git_mode
  run_prebuild "$TMP_DIR/af_git.log"
  second_key="$(extract_key "AFNetworking" "$TMP_DIR/af_git.log")"
  assert_non_empty "$second_key" "AFNetworking key missing in git mode"
  assert_not_equal "$first_key" "$second_key" "AFNetworking key should change when switching source declaration"

  set_afnetworking_version_mode
  run_prebuild "$TMP_DIR/af_v2.log"
  third_key="$(extract_key "AFNetworking" "$TMP_DIR/af_v2.log")"
  assert_equal "$first_key" "$third_key" "AFNetworking key should return after switching back"
}

test_dev_pod_switch() {
  echo "Running dev pod source-hash regression"
  run_prebuild "$TMP_DIR/dev_v1.log"
  first_key="$(extract_key "AmrCodec" "$TMP_DIR/dev_v1.log")"
  assert_non_empty "$first_key" "AmrCodec key missing before source mutation"

  mutate_amr_source
  run_prebuild "$TMP_DIR/dev_v2.log"
  second_key="$(extract_key "AmrCodec" "$TMP_DIR/dev_v2.log")"
  assert_non_empty "$second_key" "AmrCodec key missing after source mutation"
  assert_not_equal "$first_key" "$second_key" "AmrCodec key should change when local source changes"

  run_prebuild "$TMP_DIR/dev_v3.log"
  third_key="$(extract_key "AmrCodec" "$TMP_DIR/dev_v3.log")"
  assert_equal "$second_key" "$third_key" "AmrCodec key should stabilize when source stops changing"
}

prepare_logs

case "${1:-all}" in
  afnetworking-switch)
    test_afnetworking_switch
    ;;
  dev-pod-switch)
    test_dev_pod_switch
    ;;
  all)
    test_afnetworking_switch
    test_dev_pod_switch
    ;;
  *)
    echo "Unknown mode: $1" >&2
    echo "Usage: $0 [afnetworking-switch|dev-pod-switch|all]" >&2
    exit 1
    ;;
esac

echo "Integration checks passed"
