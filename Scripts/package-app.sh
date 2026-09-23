#!/bin/zsh

# Builds a release binary and wraps it in a minimal LSUIElement application.
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
dist_dir="${project_dir}/dist"
app_dir="${dist_dir}/QuotaBar.app"
contents_dir="${app_dir}/Contents"

cd "${project_dir}"
swift build -c release --product QuotaBar
bin_path="$(swift build -c release --show-bin-path)"

mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources"
rm -f "${contents_dir}/MacOS/QuotaBar"
cp "${bin_path}/QuotaBar" "${contents_dir}/MacOS/QuotaBar"
cp "${project_dir}/Resources/Info.plist" "${contents_dir}/Info.plist"

# Re-sign the completed bundle after Info.plist is present. SwiftPM's linker
# signature covers only the executable and can be rejected by LaunchServices
# with "code has no resources but signature indicates they must be present".
codesign --force --deep --sign - "${app_dir}"

echo "Created ${app_dir}"
