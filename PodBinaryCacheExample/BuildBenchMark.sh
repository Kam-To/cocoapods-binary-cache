# Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
# Use of this source code is governed by an MIT-style license that can be found in the LICENSE file

build_project() {
  echo "param: " $1
  rm -rf Pods
  rm -rf DerivedData

  start_prebuild_time="$(date -u +%s)"
  if [ $1 = "cache_on" ]; then
    echo "prebuild binary cache"
    bundle exec pod binary prebuild
  fi
  end_prebuild_time="$(date -u +%s)"
  prebuild_cache_time="$(($end_prebuild_time-$start_prebuild_time))"
  echo 'prebuild_cache_time: ' $prebuild_cache_time

  echo "Install pods"
  start_install_time="$(date -u +%s)"
  bundle exec pod install
  end_install_time="$(date -u +%s)"
  pod_install_time="$(($end_install_time-$start_install_time))"
  echo 'pod_install_time:' $pod_install_time

  start_build_time="$(date -u +%s)"
  time xcodebuild -workspace PodBinCacheExample.xcworkspace -scheme PodBinCacheExample -configuration Debug -sdk iphonesimulator ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES >/dev/null 2>&1
  end_build_time="$(date -u +%s)"
  xcodebuild_time="$(($end_build_time-$start_build_time))"
  echo 'xcodebuild_time:' $xcodebuild_time
}

export IS_POD_BINARY_CACHE_ENABLED='false'
start_time="$(date -u +%s)"
build_project "cache_off"
end_time="$(date -u +%s)"
buildtime_without_prebuild="$(($end_time-$start_time))"

export IS_POD_BINARY_CACHE_ENABLED='true'

start_time="$(date -u +%s)"
build_project "cache_on"
end_time="$(date -u +%s)"
buildtime_with_prebuild="$(($end_time-$start_time))"

echo '-------------------'
echo "Build time without prebuild: $buildtime_without_prebuild \nBuild time with prebuild: $buildtime_with_prebuild"
