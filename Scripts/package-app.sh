#!/bin/zsh

# Builds a release binary and wraps it in a minimal LSUIElement application.
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
dist_dir="${project_dir}/dist"
app_dir="${dist_dir}/CodexQuotaMonitor.app"
contents_dir="${app_dir}/Contents"

cd "${project_dir}"
swift build -c release --product CodexQuotaMonitor
bin_path="$(swift build -c release --show-bin-path)"

mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources"
rm -f "${contents_dir}/MacOS/CodexQuotaMonitor"
cp "${bin_path}/CodexQuotaMonitor" "${contents_dir}/MacOS/CodexQuotaMonitor"
cp "${project_dir}/Resources/Info.plist" "${contents_dir}/Info.plist"

echo "Created ${app_dir}"
