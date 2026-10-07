#!/bin/sh
set -eu
plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
developer_dir=$(xcode-select -p)
platform_dir="$developer_dir/Platforms/MacOSX.platform/Developer"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/smf-apple-pay-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun --sdk macosx swiftc \
  -I "$platform_dir/usr/lib" -L "$platform_dir/usr/lib" \
  -F "$platform_dir/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$platform_dir/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$platform_dir/usr/lib" \
  -module-cache-path "$test_dir/modules" \
  "$plugin_root/ios/Sources/SMFCapacitorBraintreePluginPlugin/ApplePayLifecycle.swift" \
  "$plugin_root/ios/Sources/SMFCapacitorBraintreePluginPlugin/ApplePayDismissalBarrier.swift" \
  "$plugin_root/ios/Sources/SMFCapacitorBraintreePluginPlugin/ApplePayRequestConfiguration.swift" \
  "$plugin_root/ios/Tests/SMFCapacitorBraintreePluginPluginTests/ApplePayLifecycleTests.swift" \
  "$plugin_root/scripts/ApplePayLifecycleTestRunner.swift" \
  -o "$test_dir/tests"
DYLD_FRAMEWORK_PATH="$platform_dir/Library/PrivateFrameworks" "$test_dir/tests"
